<?php

namespace Tests\Unit;

use App\CustomMailDriver\AzureCommunicationServicesTransport;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Symfony\Component\Mailer\Envelope;
use Symfony\Component\Mailer\Exception\TransportExceptionInterface;
use Symfony\Component\Mime\Address;
use Symfony\Component\Mime\Email;
use Tests\TestCase;

class AzureCommunicationServicesTransportTest extends TestCase
{
    #[Test]
    public function it_sends_email_to_azure_communication_services(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://example.communication.azure.com/emails:send*' => Http::response(['id' => 'operation-id'], 202),
        ]);

        $transport = new AzureCommunicationServicesTransport(
            'https://example.communication.azure.com',
            base64_encode('test-key'),
        );

        $email = (new Email)
            ->from(new Address('DoNotReply@anon.bc3.tech', 'AnonAddy'))
            ->to(new Address('first@example.com', 'First Recipient'))
            ->cc('copy@example.com')
            ->bcc('hidden@example.com')
            ->replyTo('reply@example.com')
            ->subject('Verify your email')
            ->text('Plain body')
            ->html('<p>HTML body</p>');
        $email->getHeaders()->addTextHeader('X-Test-Header', 'test-value');

        $transport->send($email);

        Http::assertSent(function (Request $request): bool {
            $payload = $request->data();

            $this->assertSame('POST', $request->method());
            $this->assertSame('https://example.communication.azure.com/emails:send?api-version=2023-03-31', (string) $request->url());
            $this->assertSame('DoNotReply@anon.bc3.tech', $payload['senderAddress']);
            $this->assertSame('Verify your email', $payload['content']['subject']);
            $this->assertSame('Plain body', $payload['content']['plainText']);
            $this->assertSame('<p>HTML body</p>', $payload['content']['html']);
            $this->assertSame('test-value', $payload['headers']['X-Test-Header']);
            $this->assertSame([['address' => 'reply@example.com']], $payload['replyTo']);
            $this->assertSame([['address' => 'first@example.com', 'displayName' => 'First Recipient']], $payload['recipients']['to']);
            $this->assertSame([['address' => 'copy@example.com']], $payload['recipients']['cc']);
            $this->assertSame([['address' => 'hidden@example.com']], $payload['recipients']['bcc']);

            $this->assertRequestIsSigned($request);

            return true;
        });
    }

    #[Test]
    public function it_uses_envelope_recipients_for_delivery(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://example.communication.azure.com/emails:send*' => Http::response([], 202),
        ]);

        $transport = new AzureCommunicationServicesTransport(
            'https://example.communication.azure.com',
            base64_encode('test-key'),
        );

        $email = (new Email)
            ->from('DoNotReply@anon.bc3.tech')
            ->to('visible@example.com')
            ->subject('Forwarded message')
            ->text('Forwarded body');

        $envelope = new Envelope(
            new Address('DoNotReply@anon.bc3.tech'),
            [new Address('actual@example.com')]
        );

        $transport->send($email, $envelope);

        Http::assertSent(function (Request $request): bool {
            $payload = $request->data();

            $this->assertSame([
                [
                    'address' => 'actual@example.com',
                    'displayName' => 'visible@example.com',
                ],
            ], $payload['recipients']['to']);
            $this->assertArrayNotHasKey('bcc', $payload['recipients']);

            return true;
        });
    }

    #[Test]
    public function it_uses_the_configured_sender_address_for_forwarded_email(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://example.communication.azure.com/emails:send*' => Http::response([], 202),
        ]);

        $transport = new AzureCommunicationServicesTransport(
            'https://example.communication.azure.com',
            base64_encode('test-key'),
            'DoNotReply@anon.bc3.tech',
        );

        $email = (new Email)
            ->from('brandon@bc3.tech')
            ->to('visible-alias@b.anon.bc3.tech')
            ->replyTo('reply-token@anon.bc3.tech')
            ->subject('Forwarded message')
            ->text('Forwarded body');

        $envelope = new Envelope(
            new Address('bounce-token@anon.bc3.tech'),
            [new Address('hurlburb@microsoft.com')]
        );

        $transport->send($email, $envelope);

        Http::assertSent(function (Request $request): bool {
            $payload = $request->data();

            $this->assertSame('DoNotReply@anon.bc3.tech', $payload['senderAddress']);
            $this->assertSame([['address' => 'reply-token@anon.bc3.tech']], $payload['replyTo']);
            $this->assertSame([
                [
                    'address' => 'hurlburb@microsoft.com',
                    'displayName' => 'visible-alias@b.anon.bc3.tech',
                ],
            ], $payload['recipients']['to']);

            return true;
        });
    }

    #[Test]
    public function it_uses_the_generated_from_address_as_reply_to_when_using_a_configured_sender(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://example.communication.azure.com/emails:send*' => Http::response([], 202),
        ]);

        $transport = new AzureCommunicationServicesTransport(
            'https://example.communication.azure.com',
            base64_encode('test-key'),
            'DoNotReply@anon.bc3.tech',
        );

        $email = (new Email)
            ->from(new Address('first+brandon=bc3.tech@b.anon.bc3.tech', 'Brandon at bc3.tech'))
            ->to('visible-alias@b.anon.bc3.tech')
            ->subject('Forwarded message')
            ->text('Forwarded body');

        $envelope = new Envelope(
            new Address('bounce-token@anon.bc3.tech'),
            [new Address('hurlburb@microsoft.com')]
        );

        $transport->send($email, $envelope);

        Http::assertSent(function (Request $request): bool {
            $payload = $request->data();

            $this->assertSame('DoNotReply@anon.bc3.tech', $payload['senderAddress']);
            $this->assertSame([
                [
                    'address' => 'first+brandon=bc3.tech@b.anon.bc3.tech',
                    'displayName' => 'Brandon at bc3.tech',
                ],
            ], $payload['replyTo']);
            $this->assertSame([
                [
                    'address' => 'hurlburb@microsoft.com',
                    'displayName' => 'visible-alias@b.anon.bc3.tech',
                ],
            ], $payload['recipients']['to']);

            return true;
        });
    }

    #[Test]
    public function it_throws_when_azure_rejects_the_message(): void
    {
        Http::preventStrayRequests();
        Http::fake([
            'https://example.communication.azure.com/emails:send*' => Http::response('invalid sender', 400),
        ]);

        $transport = new AzureCommunicationServicesTransport(
            'https://example.communication.azure.com',
            base64_encode('test-key'),
        );

        $email = (new Email)
            ->from('DoNotReply@anon.bc3.tech')
            ->to('first@example.com')
            ->subject('Verify your email')
            ->text('Plain body');

        $this->expectException(TransportExceptionInterface::class);
        $this->expectExceptionMessage('Azure Communication Services rejected the email: 400 invalid sender');

        $transport->send($email);
    }

    private function assertRequestIsSigned(Request $request): void
    {
        $date = $request->header('x-ms-date')[0];
        $contentHash = base64_encode(hash('sha256', $request->body(), true));
        $stringToSign = "POST\n/emails:send?api-version=2023-03-31\n{$date};example.communication.azure.com;{$contentHash}";
        $signature = base64_encode(hash_hmac('sha256', $stringToSign, 'test-key', true));

        $this->assertSame($contentHash, $request->header('x-ms-content-sha256')[0]);
        $this->assertSame(
            'HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature='.$signature,
            $request->header('Authorization')[0],
        );
    }
}
