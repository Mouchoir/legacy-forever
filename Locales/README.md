# Translations

Every phrase Legacy Forever writes goes through `L`, so it can be translated. The output of the `/lf audit` and
`/lf criteria` debug commands stays in English.

French is Brainc3ll's translation, with the lines added since then machine translated. German, Spanish (esES and
esMX), Korean, Brazilian Portuguese, Russian and Chinese (zhCN and zhTW) are machine translated: such a file starts
with a `-- Machine translated` comment, and a machine line in a human file ends `-- mt`. A human correction replaces
the machine line and drops its mark; the first one in a machine-translated file swaps that file's header for a `-- mt`
on each line still machine translated, so a later machine pass leaves the corrections alone. There is no Italian file,
because the WoW: Forever client has no Italian. `python3 tools/check_locales.py` checks every file and prints its
coverage.

To correct a line, edit `Locales/<locale>.lua` and open a pull request. To add a language the client offers, copy
`phrases.txt` to `Locales/<locale>.lua`, change the locale in its `GetLocale` line and translate the right-hand side of
each line. Anything you leave out stays in English. Then add `Locales\<locale>.lua` to `LegacyForever.toc`, right after
`Locales\enUS.lua`, and open a pull request. If that's a hassle, paste your lines into a
[translation issue](https://github.com/cjber/legacy-forever/issues/new?template=translation.yml) and I'll add them.

Zone, achievement and objective names come from the game, so they are already in your language.
