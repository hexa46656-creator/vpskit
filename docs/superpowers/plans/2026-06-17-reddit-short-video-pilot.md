# Reddit Short-Video Revenue Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Launch a $25 short-video editing offer, contact qualified Reddit buyers, and attempt to receive and fulfill one paid order within 24 hours.

**Architecture:** Keep account actions in the browser and production assets in a small local experiment folder. Use Stripe Payment Links for checkout, a synthetic self-owned sample for proof of capability, and human-reviewed Reddit proposals for acquisition. Every public post, private message, upload, payment action, CAPTCHA, or identity step remains an action-time confirmation point.

**Tech Stack:** Chrome, Reddit, Stripe Payment Links, FFmpeg/ffprobe, Markdown experiment logs, H.264/AAC MP4.

---

## File Map

- Create: `experiments/reddit-video-pilot/README.md` — offer scope, price, and operating rules.
- Create: `experiments/reddit-video-pilot/candidates.md` — qualified Reddit opportunities and rejection reasons.
- Create: `experiments/reddit-video-pilot/outreach.md` — approved proposal variants and send status.
- Create: `experiments/reddit-video-pilot/ledger.md` — timestamps, replies, payment, delivery, and final result.
- Create: `experiments/reddit-video-pilot/sample/sample-script.txt` — original demonstration script.
- Create: `experiments/reddit-video-pilot/sample/sample.srt` — demonstration captions.
- Create: `experiments/reddit-video-pilot/sample/sample.mp4` — 9:16 public portfolio sample.

### Task 1: Verify account readiness

**Files:**
- Reference: `docs/superpowers/specs/2026-06-17-reddit-short-video-pilot-design.md`

- [ ] **Step 1: Open Reddit in the existing Chrome profile**

Navigate to `https://www.reddit.com/` and inspect only the visible signed-in state. Do not read cookies, stored passwords, or browser storage.

Expected: a visible username/avatar, or a login page requiring user takeover.

- [ ] **Step 2: Verify Reddit participation eligibility**

Open the account profile and record only public account age, visible karma, and any visible posting restriction.

Expected: enough information to decide whether replies or posts are permitted without attempting either action.

- [ ] **Step 3: Switch Stripe from sandbox to the real account**

Use the visible `切换至真实账户` control. If Stripe requests login, OTP, KYC, bank details, tax information, or acceptance of new terms, stop and hand control to the user.

Expected: the Stripe dashboard no longer displays `沙盒` or `[测试]`.

- [ ] **Step 4: Verify real-payment activation**

Inspect the Stripe account status and payouts area without exposing financial details in logs.

Expected: the account can accept live payments. If activation is incomplete, mark Stripe as blocked and use Payoneer only after confirming that it supports a customer-facing payment request for this account.

### Task 2: Create the experiment workspace

**Files:**
- Create: `experiments/reddit-video-pilot/README.md`
- Create: `experiments/reddit-video-pilot/candidates.md`
- Create: `experiments/reddit-video-pilot/outreach.md`
- Create: `experiments/reddit-video-pilot/ledger.md`

- [ ] **Step 1: Create the operating README**

Write the exact offer: one 30–60 second 9:16 clip, captions, one revision, six-hour delivery, $25 price, and watermarked preview before payment.

- [ ] **Step 2: Create the candidate tracker**

Use this table:

```markdown
| Found (PT) | URL | Buyer need | Posted | Budget | Fit | Competition | Status | Reason |
|---|---|---|---|---:|---|---|---|---|
```

- [ ] **Step 3: Create the outreach tracker**

Use this table:

```markdown
| Candidate URL | Proposal text | User approved | Sent (PT) | Reply | Next action |
|---|---|---|---|---|---|
```

- [ ] **Step 4: Create the experiment ledger**

Use these headings: `Start`, `Account readiness`, `Sample`, `Candidates`, `Outreach`, `Replies`, `Payment`, `Delivery`, and `Final result`.

- [ ] **Step 5: Verify workspace contents**

Run:

```bash
rg --files experiments/reddit-video-pilot
```

Expected: the four Markdown files appear, with no secrets or personal financial data.

### Task 3: Produce an original portfolio sample

**Files:**
- Create: `experiments/reddit-video-pilot/sample/sample-script.txt`
- Create: `experiments/reddit-video-pilot/sample/sample.srt`
- Create: `experiments/reddit-video-pilot/sample/sample.mp4`

- [ ] **Step 1: Write an original 20-second script**

Use this copy:

```text
Three seconds decide whether someone keeps watching. Start with the result, remove every pause, and make each caption easy to read. One useful idea, one clean visual rhythm, one clear call to action—that is a short people finish.
```

- [ ] **Step 2: Create matching captions**

Create four caption blocks covering 00:00:00–00:00:20, with no line longer than 42 characters.

- [ ] **Step 3: Generate local narration**

Run:

```bash
say -v Samantha -r 185 -f experiments/reddit-video-pilot/sample/sample-script.txt -o experiments/reddit-video-pilot/sample/narration.aiff
```

Expected: `narration.aiff` exists and contains audible narration.

- [ ] **Step 4: Render the vertical sample**

Show this complete FFmpeg command to the user immediately before execution, as required by the project rules:

```bash
ffmpeg -f lavfi -i "color=c=0x111827:s=1080x1920:r=30:d=20" -i experiments/reddit-video-pilot/sample/narration.aiff -vf "subtitles=experiments/reddit-video-pilot/sample/sample.srt:force_style='FontName=Arial,FontSize=22,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=3,Outline=2,Shadow=0,Alignment=2,MarginV=260',format=yuv420p" -c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k -shortest -movflags +faststart experiments/reddit-video-pilot/sample/sample.mp4
```

Codec rationale: H.264/AAC maximizes browser and social-platform compatibility; CRF 18 preserves high quality; `+faststart` improves web playback.

- [ ] **Step 5: Verify the rendered file**

Run:

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,pix_fmt -of default=noprint_wrappers=1 experiments/reddit-video-pilot/sample/sample.mp4
```

Expected: `codec_name=h264`, `width=1080`, `height=1920`, and `pix_fmt=yuv420p`.

- [ ] **Step 6: Publish a view-only sample after approval**

Present `sample.mp4`, the destination Google Drive account, and the proposed view-only permission to the user. After action-time approval, upload the file, enable link viewing without edit permission, verify the link in a logged-out view, and record only the public view URL in `ledger.md`.

### Task 4: Create the live Stripe checkout

**Files:**
- Modify: `experiments/reddit-video-pilot/ledger.md`

- [ ] **Step 1: Prepare the product fields**

Use:

```text
Name: One Short-Form Video Edit
Price: $25.00 USD, one time
Description: One 30–60 second vertical video edit with captions, one revision, and delivery within six hours after receiving usable source material.
```

- [ ] **Step 2: Enter the product in Stripe live mode**

Do not enable subscriptions, automatic tax, phone collection, address collection, promotional codes, or saved payment details.

- [ ] **Step 3: Confirm before creating the live Payment Link**

Show the user the product name, price, description, and customer data collected. Creating the link is an external account change and requires action-time confirmation.

- [ ] **Step 4: Create and verify the link**

After approval, create the link and open its checkout page without submitting a payment.

Expected: $25.00 USD, one-time purchase, correct product name, and a `buy.stripe.com` URL.

- [ ] **Step 5: Record the link safely**

Record the public checkout URL in the `Payment` section of `ledger.md`. Do not record Stripe account IDs, bank details, keys, or customer data.

### Task 5: Qualify live Reddit opportunities

**Files:**
- Modify: `experiments/reddit-video-pilot/candidates.md`

- [ ] **Step 1: Search recent buyer-intent posts**

Search Reddit and Google for posts from the last 48 hours containing combinations of `hiring`, `short-form video editor`, `reels editor`, `TikTok editor`, and `YouTube Shorts editor`.

- [ ] **Step 2: Apply qualification rules**

Keep only posts that are open, allow remote applicants, describe a real editing need, do not require deceptive engagement, and have a budget compatible with at least $25 per usable clip.

- [ ] **Step 3: Reject risky or poor-fit leads**

Reject posts requesting unpaid full samples, credential sharing, copyrighted reuploads, artificial engagement, off-platform software installation, crypto payments, or payment before the client provides a clear brief.

- [ ] **Step 4: Record 10–15 candidates**

For each candidate, record the URL, buyer need, posting recency, budget, fit, visible competition, and the reason for keeping or rejecting it.

- [ ] **Step 5: Select the best five**

Rank candidates by recency, clear budget, fit with the sample, low visible competition, and likelihood of same-day delivery.

Expected: five leads suitable for individualized proposals.

### Task 6: Draft and send individualized proposals

**Files:**
- Modify: `experiments/reddit-video-pilot/outreach.md`
- Modify: `experiments/reddit-video-pilot/ledger.md`

- [ ] **Step 1: Draft one proposal per selected lead**

Use this structure, replacing the opening sentence with verified details from each post before presenting it to the user:

```text
Hi — I saw you're hiring an editor for short-form vertical content. I can turn one source video into a clean 30–60 second vertical edit with captions and one revision, delivered within six hours. My pilot price is $25. I can first send a short watermarked preview so you can judge the pacing before paying. I also have a view-only sample ready.
```

Insert the verified Google Drive view URL from `ledger.md` into the final sentence before requesting approval to send.

- [ ] **Step 2: Remove unsupported claims**

Confirm that no proposal claims client results, years of experience, prior customers, guaranteed views, or skills not demonstrated by the sample.

- [ ] **Step 3: Ask for action-time approval**

Present the exact Reddit recipient/post and exact message text. Sending replies or private messages represents the user and requires confirmation immediately before sending.

- [ ] **Step 4: Send only approved proposals**

Send no more than five initial proposals, spaced naturally and only where subreddit rules permit. Record the timestamp and resulting URL or conversation state.

- [ ] **Step 5: Check replies without spamming**

Check at reasonable intervals. Send at most one follow-up after six hours, only if the original post remains open and subreddit rules allow it.

### Task 7: Close, fulfill, and record the experiment

**Files:**
- Modify: `experiments/reddit-video-pilot/ledger.md`
- Create: `experiments/reddit-video-pilot/orders/order-001/brief.md`
- Create: `experiments/reddit-video-pilot/orders/order-001/delivery.md`

- [ ] **Step 1: Capture an interested buyer's brief**

Record source URL/file, desired duration, aspect ratio, caption language, reference style, deadline, and confirmation that the buyer has rights to the source.

- [ ] **Step 2: Produce a watermarked preview**

Create only 10–15 seconds. Do not publish or reuse the buyer's material outside the private proposal conversation.

- [ ] **Step 3: Send the payment link after approval**

Present the exact message and destination for user confirmation before sending the Stripe URL.

- [ ] **Step 4: Verify payment in Stripe**

Use the Stripe dashboard's successful-payment status as the authoritative signal. Do not rely only on buyer screenshots or messages.

- [ ] **Step 5: Render and verify the final delivery**

Confirm H.264 video, AAC audio, 1080×1920 output, captions, duration, and absence of the watermark before upload.

- [ ] **Step 6: Deliver after action-time approval**

Show the exact destination and file before uploading or sending it to the buyer.

- [ ] **Step 7: Write the final result**

Record gross payment, visible Stripe fee, net amount, outreach count, reply count, delivery status, elapsed time, and lessons. Do not include customer financial data or private identifiers.

Expected: either one completed paid order or a complete 24-hour validation record explaining the failed conversion point.

### Task 8: Final verification

**Files:**
- Verify: `experiments/reddit-video-pilot/`

- [ ] **Step 1: Scan for secrets**

Run:

```bash
rg -n -i "api[_ -]?key|secret|password|token|card number|routing number|account number" experiments/reddit-video-pilot
```

Expected: no secrets or financial credentials.

- [ ] **Step 2: Validate the sample and any delivery files**

Run `ffprobe` against every MP4 created by the experiment and confirm the required codecs and dimensions.

- [ ] **Step 3: Review the experiment ledger**

Expected: timestamps and outcomes are complete, claims match browser evidence, and no unsent proposal is marked as sent.

- [ ] **Step 4: Commit non-sensitive experiment artifacts**

Do not commit customer source media, customer deliveries, payment data, or private messages. Commit only the operating documents, synthetic sample assets when reasonably sized, and sanitized experiment summary.
