# The 3-Second Challenge

A full-screen Tech Club arcade timing game with a public leaderboard and a private admin dashboard.

## Features

- Registration with unique enrollment numbers for each event
- Millisecond timing with `performance.now()` and immediate STOP capture
- Database-enforced attempt limits and best-attempt leaderboard sorting
- Public leaderboard that refreshes every five seconds without showing enrollment numbers
- Password-protected admin dashboard, participant search, CSV export, attempt configuration, and event reset
- Mobile and laptop layouts, keyboard focus states, reduced-motion support, and optional synthesized sound effects
- Automatic return to a compact entry and leaderboard screen 10 seconds after a saved attempt

## Run locally

Use Node.js 20.9 or newer. Run `npm ci`, copy `.env.example` to `.env.local`, set the five values, then run `npm run dev`.

## Database

The database setup is in `supabase/game.sql`. It creates an isolated `game_private` schema and guarded RPC functions in an existing Supabase project. Apply it once using a privileged SQL editor or migration. The SQL generates a random API secret in `game_private.settings`; retrieve that value for `GAME_DB_SECRET` in the server environment. Never expose `GAME_DB_SECRET`, `ADMIN_PASSWORD`, or `SESSION_SECRET` to browser code.

The private schema is not exposed through the Data API. Public RPCs require the server-held API secret. The Next.js server routes check an HttpOnly participant cookie or a signed admin session before using those RPCs. The enrollment number is never returned by public endpoints.

## Deploy

Set all five environment variables in Vercel and deploy the repository as a Next.js project. The included `build` script uses Webpack for compatibility with the production build. The admin dashboard is at `/admin`.

Changing the admin password requires updating `ADMIN_PASSWORD` in Vercel and redeploying. Set `SESSION_SECRET` to a separate random value.

## Event operations

The default is one attempt per player. Admins can set 1–20 attempts. Starting a new event changes the active event ID: old records remain in the private database, while the current leaderboard and registrations start fresh. Players must register again for the new event.

After a result, the screen counts down from 10 seconds before handing the device to the next player. A player with attempts left can choose **Play Again** during the countdown, or enter the same name and enrollment number on the handoff screen while their session remains on that device.

Browser timing is accurate for normal play, but browser clocks and client requests are ultimately controlled by participants. For prize-bearing competitions, supervise the stall and review suspicious scores.
