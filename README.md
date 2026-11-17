# SSA Audit Tracker

A single-page audit testing tool for financial documents, aligned to Singapore Standards on Auditing (SSA) and SFRS(I).

- **Issue tracker**: issues ranked by risk (High / Medium / Low) and priority (P1–P3), with amounts measured against overall materiality, performance materiality and the clearly trivial threshold (SSA 320, SSA 450).
- **Where to find it**: file, sheet, Excel row numbers and columns for every issue, with the flagged lines highlighted.
- **Standards links**: each issue cites the relevant SSA / SFRS(I) paragraphs and highlights them in the built-in library.
- **Excel upload**: `.xlsx`, `.xls` and `.csv` files are parsed in the browser (SheetJS) and run through automated tests (journal entry testing, cut-off, duplicates, round sums, weekend postings, related parties, estimates, sequence gaps, Benford, sign anomalies, formula errors).

All data stays in the browser's `localStorage`. Nothing is uploaded to a server.

> Paragraph text in the app is a short paraphrase. Always confirm against the official SSA (ISCA) and SFRS(I) (ASC) text for the engagement period.

## Deploy on Vercel

This is a static site with no build step.

1. In Vercel, choose **Add New → Project** and import this repository.
2. Framework preset: **Other**. Leave Build Command and Output Directory empty (root directory `./`).
3. Click **Deploy**.

Or from the command line: `npx vercel --prod` in this folder.

## Run locally

Open `index.html` in a browser, or serve the folder: `npx serve .`
