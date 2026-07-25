<?php

namespace App\CustomMailDriver;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Http;
use Symfony\Component\Mailer\Envelope;
use Symfony\Component\Mailer\Exception\TransportException;
use Symfony\Component\Mailer\SentMessage;
use Symfony\Component\Mailer\Transport\AbstractTransport;
use Symfony\Component\Mime\Address;
use Symfony\Component\Mime\Email;
use Symfony\Component\Mime\Part\DataPart;

class AzureCommunicationServicesTransport extends AbstractTransport
{
    public function __construct(
        private readonly string $endpoint,
        private readonly string $accessKey,
        private readonly ?string $senderAddress = null,
        private readonly string $apiVersion = '2023-03-31',
        private readonly int $timeout = 60,
        private readonly int $connectTimeout = 10,
    ) {
        parent::__construct();
    }

    public function __toString(): string
    {
        return 'acs';
    }

    protected function doSend(SentMessage $message): void
    {
        $email = $message->getOriginalMessage();

        if (! $email instanceof Email) {
            throw new TransportException('Azure Communication Services mail transport only supports Symfony Email messages.');
        }

        $payload = $this->payload($email, $message->getEnvelope());
        $response = $this->sendPayload($payload);

        if (! $response->successful()) {
            throw new TransportException('Azure Communication Services rejected the email: '.$response->status().' '.$response->body());
        }

        if ($id = $this->messageId($response)) {
            $message->setMessageId($id);
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function payload(Email $email, Envelope $envelope): array
    {
        $from = $this->resolveFromAddress($email);

        $recipients = $this->recipients($email, $envelope);

        if ($recipients === []) {
            throw new TransportException('Azure Communication Services requires at least one recipient.');
        }

        $payload = [
            'senderAddress' => $this->senderAddress($from),
            'recipients' => $recipients,
            'content' => [
                'subject' => $email->getSubject() ?? '',
            ],
        ];

        if ($email->getTextBody() !== null) {
            $payload['content']['plainText'] = $email->getTextBody();
        }

        if ($email->getHtmlBody() !== null) {
            $payload['content']['html'] = $email->getHtmlBody();
        }

        if ($replyTo = $this->replyToAddresses($email, $from)) {
            $payload['replyTo'] = $replyTo;
        }

        if ($headers = $this->customHeaders($email)) {
            $payload['headers'] = $headers;
        }

        if ($attachments = $this->attachments($email)) {
            $payload['attachments'] = $attachments;
        }

        return $payload;
    }

    private function resolveFromAddress(Email $email): Address
    {
        $from = Arr::first($email->getFrom());

        if (! $from instanceof Address) {
            throw new TransportException('Azure Communication Services requires a sender address.');
        }

        return $from;
    }

    /**
     * @return array<string, list<array{address: string, displayName?: string}>>
     */
    private function recipients(Email $email, Envelope $envelope): array
    {
        $envelopeRecipients = $this->keyedAddresses($envelope->getRecipients());
        $recipients = [];

        $to = $this->matchingAddresses($email->getTo(), $envelopeRecipients);
        if ($to !== []) {
            $recipients['to'] = $to;
        }

        $cc = $this->matchingAddresses($email->getCc(), $envelopeRecipients);
        if ($cc !== []) {
            $recipients['cc'] = $cc;
        }

        $bcc = $this->matchingAddresses($email->getBcc(), $envelopeRecipients);

        foreach (array_keys($envelopeRecipients) as $address) {
            if (! $this->addressInPayload($address, $recipients) && ! $this->addressInList($address, $bcc)) {
                if ($recipients === [] && $bcc === []) {
                    $recipients['to'][] = $this->envelopeOnlyRecipient($envelopeRecipients[$address], $email);

                    continue;
                }

                $bcc[] = ['address' => $envelopeRecipients[$address]->getAddress()];
            }
        }

        if ($bcc !== []) {
            $recipients['bcc'] = $bcc;
        }

        return $recipients;
    }

    /**
     * @param  Address[]  $addresses
     * @return array<string, Address>
     */
    private function keyedAddresses(array $addresses): array
    {
        $keyed = [];

        foreach ($addresses as $address) {
            $keyed[strtolower($address->getAddress())] = $address;
        }

        return $keyed;
    }

    /**
     * @param  Address[]  $addresses
     * @param  array<string, Address>  $allowed
     * @return list<array{address: string, displayName?: string}>
     */
    private function matchingAddresses(array $addresses, array $allowed): array
    {
        $matched = [];

        foreach ($addresses as $address) {
            $key = strtolower($address->getAddress());

            if (! array_key_exists($key, $allowed)) {
                continue;
            }

            $matched[] = $this->acsAddress($address);
        }

        return $matched;
    }

    /**
     * @param  Address[]  $addresses
     * @return list<array{address: string, displayName?: string}>
     */
    private function acsAddresses(array $addresses): array
    {
        return array_map(fn (Address $address): array => $this->acsAddress($address), $addresses);
    }

    /**
     * @return list<array{address: string, displayName?: string}>
     */
    private function replyToAddresses(Email $email, Address $from): array
    {
        if ($email->getReplyTo() !== []) {
            return $this->acsAddresses($email->getReplyTo());
        }

        if ($this->senderAddress === null || strcasecmp($this->senderAddress, $from->getAddress()) === 0) {
            return [];
        }

        return [$this->acsAddress($from)];
    }

    private function senderAddress(Address $from): string
    {
        if ($this->senderAddress === null) {
            return $from->getAddress();
        }

        return $this->senderAddress;
    }

    /**
     * @return array{address: string, displayName?: string}
     */
    private function envelopeOnlyRecipient(Address $recipient, Email $email): array
    {
        $acsRecipient = ['address' => $recipient->getAddress()];
        $visibleRecipient = Arr::first($email->getTo());

        if ($visibleRecipient instanceof Address) {
            $acsRecipient['displayName'] = $visibleRecipient->getAddress();
        }

        return $acsRecipient;
    }

    /**
     * @return array{address: string, displayName?: string}
     */
    private function acsAddress(Address $address): array
    {
        $acsAddress = ['address' => $address->getAddress()];

        if ($address->getName() !== '') {
            $acsAddress['displayName'] = $address->getName();
        }

        return $acsAddress;
    }

    /**
     * @param  array<string, list<array{address: string, displayName?: string}>>  $recipients
     */
    private function addressInPayload(string $address, array $recipients): bool
    {
        foreach ($recipients as $recipientGroup) {
            if ($this->addressInList($address, $recipientGroup)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param  list<array{address: string, displayName?: string}>  $recipients
     */
    private function addressInList(string $address, array $recipients): bool
    {
        foreach ($recipients as $recipient) {
            if (strtolower($recipient['address']) === $address) {
                return true;
            }
        }

        return false;
    }

    /**
     * @return array<string, string>
     */
    private function customHeaders(Email $email): array
    {
        $headers = [];
        $excluded = [
            'bcc',
            'cc',
            'content-transfer-encoding',
            'content-type',
            'date',
            'from',
            'mime-version',
            'reply-to',
            'return-path',
            'sender',
            'subject',
            'to',
        ];

        if ($this->shouldIncludeDisplayHeaders($email)) {
            $excluded = array_diff($excluded, ['from', 'to']);
        }

        foreach ($email->getHeaders()->all() as $header) {
            $name = $header->getName();

            if (in_array(strtolower($name), $excluded, true)) {
                continue;
            }

            $headers[$name] = $header->getBodyAsString();
        }

        return $headers;
    }

    private function shouldIncludeDisplayHeaders(Email $email): bool
    {
        if ($this->senderAddress === null) {
            return false;
        }

        $from = Arr::first($email->getFrom());

        if (! $from instanceof Address) {
            return false;
        }

        if ($from->getName() !== '') {
            return true;
        }

        return strcasecmp($this->senderAddress, $from->getAddress()) !== 0;
    }

    /**
     * @return list<array<string, string>>
     */
    private function attachments(Email $email): array
    {
        return array_map(function (DataPart $attachment): array {
            $payload = [
                'name' => $attachment->getFilename() ?? 'attachment',
                'contentType' => $attachment->getContentType(),
                'contentInBase64' => base64_encode($attachment->getBody()),
            ];

            if ($attachment->hasContentId()) {
                $payload['contentId'] = $attachment->getContentId();
            }

            return $payload;
        }, $email->getAttachments());
    }

    /**
     * @return array<string, string>
     */
    private function headers(string $body, string $pathAndQuery): array
    {
        $date = gmdate('D, d M Y H:i:s').' GMT';
        $contentHash = base64_encode(hash('sha256', $body, true));
        $signature = $this->signature("POST\n{$pathAndQuery}\n{$date};{$this->host()};{$contentHash}");

        return [
            'Authorization' => 'HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature='.$signature,
            'x-ms-date' => $date,
            'x-ms-content-sha256' => $contentHash,
        ];
    }

    private function signature(string $stringToSign): string
    {
        $key = base64_decode($this->accessKey, true);

        if ($key === false) {
            throw new TransportException('Azure Communication Services access key must be base64 encoded.');
        }

        return base64_encode(hash_hmac('sha256', $stringToSign, $key, true));
    }

    private function url(string $pathAndQuery): string
    {
        return rtrim($this->endpoint, '/').$pathAndQuery;
    }

    private function host(): string
    {
        $host = parse_url($this->endpoint, PHP_URL_HOST);

        if (! is_string($host) || $host === '') {
            throw new TransportException('Azure Communication Services endpoint must include a valid host.');
        }

        return $host;
    }

    private function messageId(Response $response): ?string
    {
        if (is_string($response->json('id'))) {
            return $response->json('id');
        }

        $operationLocation = $response->header('Operation-Location');

        if (! is_string($operationLocation) || $operationLocation === '') {
            return null;
        }

        return basename(parse_url($operationLocation, PHP_URL_PATH) ?: $operationLocation);
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private function sendPayload(array $payload): Response
    {
        $body = json_encode($payload, JSON_THROW_ON_ERROR);
        $pathAndQuery = '/emails:send?api-version='.$this->apiVersion;
        $headers = $this->headers($body, $pathAndQuery);

        return Http::timeout($this->timeout)
            ->connectTimeout($this->connectTimeout)
            ->withBody($body, 'application/json')
            ->withHeaders($headers)
            ->post($this->url($pathAndQuery));
    }
}
