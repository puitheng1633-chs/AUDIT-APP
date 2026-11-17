# SSA Audit Tracker

A single-page audit testing tool for financial documents, aligned to Singapore Standards on Auditing (SSA) and SFRS(I).

- **Issue tracker**: issues ranked by risk (High / Medium / Low) and priority (P1–P3), with amounts measured against overall materiality, performance materiality and the clearly trivial threshold (SSA 320, SSA 450).
- **Where to find it**: file, sheet, Excel row numbers and columns for every issue, with the flagged lines highlighted.
- **Standards links**: each issue cites the relevant SSA / SFRS(I) paragraphs and highlights them in the built-in library.
- **Excel upload**: `.xlsx`, `.xls` and `.csv` files are parsed in the browser (SheetJS) and run through automated tests (journal entry testing, cut-off, duplicates, round sums, weekend postings, related parties, estimates, sequence gaps, Benford, sign anomalies, formula errors).

## Sign-in and shared data (Supabase)

Users sign in with a username and password. Passwords are held by Supabase Auth (`auth.users`); the app never stores them. Each username maps to the login email `<username>@audit-app.local`.

| Table | Holds |
|---|---|
| `profiles` | username, full name, role (`admin`, `auditor`, `reviewer`), active flag; linked 1:1 to `auth.users` |
| `engagements` | entity, reporting date, currency, materiality settings |
| `audit_files` | uploaded workbooks (parsed sheets as JSON) |
| `audit_issues` | issues, status, priority, notes, SSA/SFRS(I) references, who changed them |

Row level security lets only **active** members read or change audit data. Admins manage users on the **Users** page, which calls the `manage-users` edge function (it holds the service key server-side). Issue changes reach teammates live through Supabase Realtime.

Seed users: `priya` (admin), `dan`, `marcus` (auditors), initial password `password`. Change these after first sign-in.

Schema: `supabase/migrations/`. Edge function: `supabase/functions/manage-users/`.

The publishable key in `index.html` is meant to be public; access is enforced by row level security.

> Paragraph text in the app is a short paraphrase. Always confirm against the official SSA (ISCA) and SFRS(I) (ASC) text for the engagement period.

## Deploy on Vercel

This is a static site with no build step.

1. In Vercel, choose **Add New → Project** and import this repository.
2. Framework preset: **Other**. Leave Build Command and Output Directory empty (root directory `./`).
3. Click **Deploy**.

Or from the command line: `npx vercel --prod` in this folder.

## Run locally

Open `index.html` in a browser, or serve the folder: `npx serve .`
