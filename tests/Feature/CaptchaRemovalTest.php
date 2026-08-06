<?php

namespace Tests\Feature;

use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class CaptchaRemovalTest extends TestCase
{
    #[Test]
    public function password_reset_page_does_not_show_captcha(): void
    {
        $response = $this->get('/password/reset');

        $response
            ->assertOk()
            ->assertDontSee('captcha', false)
            ->assertDontSee('Human Verification');
    }

    #[Test]
    public function username_reminder_page_does_not_show_captcha(): void
    {
        $response = $this->get('/username/reminder');

        $response
            ->assertOk()
            ->assertDontSee('captcha', false)
            ->assertDontSee('Human Verification');
    }
}
