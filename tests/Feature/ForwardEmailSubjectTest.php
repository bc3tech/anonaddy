<?php

namespace Tests\Feature;

use App\Mail\ForwardEmail;
use App\Models\Alias;
use App\Models\EmailData;
use App\Models\Rule;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class ForwardEmailSubjectTest extends TestCase
{
    use LazilyRefreshDatabase;

    #[Test]
    public function it_prepends_the_original_sender_to_the_final_forwarded_subject(): void
    {
        $user = $this->createUser();
        $alias = Alias::factory()->create([
            'user_id' => $user->id,
            'email' => 'ebay@johndoe.'.config('anonaddy.domain'),
            'local_part' => 'ebay',
            'domain' => 'johndoe.'.config('anonaddy.domain'),
        ]);
        $rule = Rule::factory()->create([
            'user_id' => $user->id,
            'actions' => [
                [
                    'type' => 'subject',
                    'value' => 'Filtered subject',
                ],
            ],
        ]);

        $email = (new ForwardEmail(
            $alias,
            $this->emailData(),
            $user->defaultRecipient,
            false,
            [$rule->id],
        ))->build();

        $this->assertSame('Will <will@anonaddy.com> - Filtered subject', $email->subject);
    }

    private function emailData(): EmailData
    {
        $emailData = new class extends EmailData
        {
            public function __construct() {}
        };

        $emailData->sender = 'will@anonaddy.com';
        $emailData->display_from = base64_encode('Will');
        $emailData->reply_to_address = null;
        $emailData->ccs = [];
        $emailData->tos = [];
        $emailData->originalCc = null;
        $emailData->originalTo = null;
        $emailData->subject = base64_encode('Original subject');
        $emailData->text = base64_encode('Original body');
        $emailData->html = '';
        $emailData->attachments = [];
        $emailData->inlineAttachments = [];
        $emailData->size = 0;
        $emailData->messageId = '';
        $emailData->listUnsubscribe = '';
        $emailData->listUnsubscribePost = '';
        $emailData->inReplyTo = '';
        $emailData->references = '';
        $emailData->originalEnvelopeFrom = 'will@anonaddy.com';
        $emailData->originalFromHeader = base64_encode('Will <will@anonaddy.com>');
        $emailData->originalReplyToHeader = '';
        $emailData->originalSenderHeader = '';
        $emailData->authenticationResults = '';
        $emailData->receivedHeaders = null;
        $emailData->failedDmarc = false;
        $emailData->isSpam = false;
        $emailData->encryptedParts = null;
        $emailData->isInlineEncrypted = false;

        return $emailData;
    }
}
