# Tweet, when the given HTML looks different.

This is a notifier, that can inspect a given web page (html) for changes
and post changes to twitter.com (or order channel).

## Installation

You system needs to have these first:

- git
- sqlite3
- perl v5.18 or newer
- cpm

Basically, this "app" a set of programs that should be scheduled as cronjob.
In this document, let `/app/tweet-html-diff/` be the installation target.

Here are the steps to manually install everything under `/app/tweet-html-diff/`

    git clone git@github.com:g0v/tweet-html-diff.git /app/tweet-html-diff/
    cd /app/tweet-html-diff/
    cpm install

## Setup: database

All states are mantained in a single SQLite database, which can be initialized
by doing this:
    
    cat init.sql | sqlite3 /app/tweet-html-diff/var/example.sqlite3

## Setup: cronjobs

Programs are split into 3 kinds of roles, one who collect new corpus, one who figures out what are new entries, the other who post something to a notification channel.

These are the ones that collect new corpus

- collect-html-diff.pl
- collect-text-diff.pl

The one that derives what are new entries:

- spew-new-entries

The ones that post entries to a notification channel

- feed-to-console.pl
- feed-to-feedro.pl
- feed-to-mastodon.pl
- feed-to-plurk.pl
- feed-to-telegram.pl

In crontab:

    */15 * * * * perl -Mlib=/app/tweet-html-diff/local/lib/perl5 /app/tweet-html-diff/collect-html-diff.pl

