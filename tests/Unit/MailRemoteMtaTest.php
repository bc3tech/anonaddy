<?php

namespace Tests\Unit;

use App\Support\MailRemoteMta;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class MailRemoteMtaTest extends TestCase
{
    #[Test]
    public function it_uses_azure_communication_services_endpoint_host_for_acs_mailer(): void
    {
        config([
            'mail.default' => 'acs',
            'mail.mailers.acs' => [
                'transport' => 'acs',
                'endpoint' => 'https://example.communication.azure.com',
            ],
            'mail.mailers.smtp.host' => 'smtp.office365.com',
        ]);

        $this->assertSame('example.communication.azure.com', MailRemoteMta::forConfiguredMailer());
    }

    #[Test]
    public function it_uses_smtp_host_for_smtp_mailer(): void
    {
        config([
            'mail.default' => 'smtp',
            'mail.mailers.smtp' => [
                'transport' => 'smtp',
                'host' => 'smtp.office365.com',
            ],
        ]);

        $this->assertSame('smtp.office365.com', MailRemoteMta::forConfiguredMailer());
    }
}
