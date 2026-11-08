// Mailer port (D-013): Resend in staging/production, Mailpit locally.

export interface EmailMessage {
  to: { email: string; name?: string };
  subject: string;
  html: string;
  text: string;
}

export interface Mailer {
  send(message: EmailMessage): Promise<void>;
}

type Fetch = typeof fetch;

export class ResendMailer implements Mailer {
  constructor(
    private readonly apiKey: string,
    private readonly from: string,
    private readonly fetcher: Fetch = fetch,
  ) {}

  async send(message: EmailMessage): Promise<void> {
    const response = await this.fetcher("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: this.from,
        to: [formatAddress(message.to)],
        subject: message.subject,
        html: message.html,
        text: message.text,
      }),
    });
    if (!response.ok) {
      throw new Error(`resend ${response.status}: ${await response.text()}`);
    }
  }
}

export class MailpitMailer implements Mailer {
  constructor(
    private readonly baseUrl: string,
    private readonly from: string,
    private readonly fetcher: Fetch = fetch,
  ) {}

  async send(message: EmailMessage): Promise<void> {
    const from = parseAddress(this.from);
    const response = await this.fetcher(`${this.baseUrl}/api/v1/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        From: { Email: from.email, Name: from.name ?? "" },
        To: [{ Email: message.to.email, Name: message.to.name ?? "" }],
        Subject: message.subject,
        HTML: message.html,
        Text: message.text,
      }),
    });
    if (!response.ok) {
      throw new Error(`mailpit ${response.status}: ${await response.text()}`);
    }
  }
}

/** Last resort when nothing is configured: logs instead of sending. */
export class ConsoleMailer implements Mailer {
  readonly sent: EmailMessage[] = [];

  send(message: EmailMessage): Promise<void> {
    this.sent.push(message);
    console.log(`[mail] to=${message.to.email} subject=${message.subject}`);
    return Promise.resolve();
  }
}

export function mailerFromEnv(
  env: (key: string) => string | undefined,
  fetcher: Fetch = fetch,
): Mailer {
  const from = env("MAIL_FROM") ?? "Socios <no-reply@socios.local>";
  const resendKey = env("RESEND_API_KEY");
  if (resendKey) return new ResendMailer(resendKey, from, fetcher);
  const mailpit = env("MAILPIT_URL");
  if (mailpit) return new MailpitMailer(mailpit, from, fetcher);
  return new ConsoleMailer();
}

export function formatAddress(address: { email: string; name?: string }) {
  return address.name ? `${address.name} <${address.email}>` : address.email;
}

export function parseAddress(value: string): { email: string; name?: string } {
  const match = value.match(/^\s*(.*?)\s*<([^>]+)>\s*$/);
  return match ? { name: match[1] || undefined, email: match[2] } : { email: value.trim() };
}
