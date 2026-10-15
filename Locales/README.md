# Translations

Legacy Forever is in English, but every phrase it writes goes through `L`, so it can be translated. The output of
the `/lf audit` and `/lf criteria` debug commands stays in English.

To add your language, copy `phrases.txt` to `Locales/<locale>.lua` (deDE, esES, esMX, frFR, itIT, koKR, ptBR,
ruRU, zhCN or zhTW), change the locale in its `GetLocale` line and translate the right-hand side of each line.
Anything you leave out stays in English. Then add `Locales\<locale>.lua` to `LegacyForever.toc`, right after
`Locales\enUS.lua`, and open a pull request. If that's a hassle, paste the file into a
[translation issue](https://github.com/cjber/legacy-forever/issues/new?template=translation.yml) and I'll add it.

Zone, achievement and objective names come from the game, so they are already in your language.
