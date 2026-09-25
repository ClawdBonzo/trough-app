# Trough ASO research: 1.4.0 (September 2026)

App Store ID 6760955550 · Health & Fitness · 12+ · live version at research time: 1.3.1 (0 ratings in every storefront except US, which has 2).

## Method

- Source: the public iTunes Search API (`https://itunes.apple.com/search?term=…&country=<cc>&entity=software&limit=25`), about 1 request/sec, run 24–25 Sep 2026. 332 queries across 15 storefronts (us, gb, au, ca, de, es, mx, fr, it, jp, kr, nl, pl, br, se).
- For each term: number of results, how many of the top 25 are *relevant* (Health/Medical/Lifestyle/Productivity/Utilities/Reference apps whose title or description mentions testosterone/TRT/peptide/hormone/injection/GLP-1 in that language), Trough's rank if it appears in the top 25, and the leading relevant apps with their rating counts (a rough measure of how strong the incumbents are).
- Caveats: the Search API is a proxy. It does not return real App Store search rankings or search volume. "Relevant results" stands in for demand plus intent match, and incumbents' rating counts stand in for how hard a term is to win. Re-run `research.py` (the term lists are in this doc) for weekly checkups and compare Trough's rank column.

## Storefront → indexed localizations (cross-localization)

Apple indexes more than one localization in many storefronts. The mapping below is the commonly cited one; confirm it against Apple's current "App Store localizations" table before relying on it.

| Storefront | Localizations indexed | How we used it |
|---|---|---|
| US | en-US + es-MX | en-US keeps English terms; es-MX keeps Spanish terms (testosterona, inyecciones), which also catch US Spanish-language searches. No English is repeated in es-MX. |
| MX | es-MX + en-US | en-US already covers "trt/testosterone/injection/tracker", so es-MX is 100% Spanish. |
| UK | en-GB | en-GB has to stand on its own: UK vocabulary (jab, bloods, blood test, oestradiol, male HRT). |
| AU | en-AU + en-GB | en-AU keywords **complement** en-GB rather than repeat it (pathology, labs, needle, schedule, site rotation, cypionate/enanthate, estradiol, pk, men). |
| CA | en-CA + fr-CA | No fr-CA localization ships yet, so en-CA's keyword field carries a few French terms (suivi, sang, analyse, hormonal). **Recommendation: add an fr-CA localization** (copy fr-FR and adapt it). |
| DE, FR, IT, ES, NL, PL, SE | native + en-GB | en-GB's "TRT / Testosterone / Injection / Blood Test / Tracker" tokens back up each European store, so native names can spend their characters on native words. |
| BR | pt-BR + en-US | Same logic as MX. |
| JP, KR | native + en-US | Same logic. "TRT" also sits in the native subtitle because JP/KR competitors use it. |

## Key findings by market

- **US**: "trt" is dominated by the Turkish broadcaster TRT (tabii, TRT Haber…), but 8 of the top 25 are TRT trackers and Trough ranks #15. "trt tracker" (22/23 relevant, Trough #21) and "trt injection" (25/25, Trough #13) are the core. TRT-specific incumbents are small (the largest has 168 ratings), so these terms are winnable. "testosterone", "testosterone injection" and "testosterone log" are highly relevant but Trough is not in the top 25, which is why "Testosterone" moves into the name. "peptide", "glp-1", "shot tracker" and "injection tracker" are saturated by GLP-1/peptide apps with thousands to tens of thousands of ratings, so we keep them as secondary keywords. "hrt", "hormone tracker" and "hormone replacement" skew to menopause and trans HRT apps (low intent), as does "estradiol". "hcg", "pinning" and "low t" return no relevant apps. "cypionate" and "enanthate" are low competition with exact intent, so both stay in.
- **UK**: people say "jab", "bloods", "blood test", "male HRT". "jab tracker" is GLP-1 territory. "bloods" and "blood test" return no relevant apps (no competition, but also no proof of demand). "male hrt" returns TRT and HRT apps (12 relevant). Drug brand names (Sustanon, Nebido, Testogel) return a few TRT apps, but we **skip them as trademarks**.
- **AU**: similar to the UK; "testosterone injection" already has Trough at #19. "pathology" is the Australian word for lab tests.
- **CA**: English behaves like the US; "testostérone" returns the same TRT apps, and a fr-CA localization would add coverage.
- **DE**: "trt" on its own is not a German search (the top result is "TRT Thailand"). Germans search "testosteron", "testosteron tracker" (22 relevant), "testosteron injektion" (Trough #10) and "testosteron spritze", and use "Spritze/Spritzen" (mostly GLP-1 "Abnehmspritze" apps) and "Blutwerte". "Testosterontherapie" and "Hormonersatztherapie" get almost no results, so people don't search those words.
- **FR**: "trt" is not searched (0 relevant). "testostérone" (22 relevant) and "injection testostérone" (Trough #19) are. The native lab word is "bilan sanguin", and a competitor is titled "TRT : Doses & Bilan Sanguin". "piqûre" mostly returns insect-bite apps, so it was dropped.
- **ES (Spain)**: "testosterona" (Trough #16), "terapia testosterona" (#4), "terapia hormonal" (#7), "inyección testosterona" (#11), "trt testosterona" (#18). The Spanish word for blood tests is "analítica/analíticas" (a competitor uses "Dosis y Analíticas"), and "pinchazo" is the everyday word for a shot.
- **MX**: "trt" alone returns 0 relevant apps. "testosterona" (19 relevant), "terapia testosterona" (Trough #2), "terapia hormonal" (#4), "inyección testosterona" (#14). "estudios de laboratorio" and "análisis de sangre" show no competition. "reemplazo hormonal" returns 0 results. In copy, Mexican Spanish uses "aplicación" for a shot, "estudios/labs" for tests and "ícono" instead of "icono".
- **IT**: "trt" is weak (3 relevant). "testosterone" (24), "terapia testosterone" (Trough #4) and "testosterone iniezioni" (Trough #4) are where Trough already ranks; "diario iniezioni" has 25/25 relevant results (GLP-1 heavy). "esami del sangue" and "analisi del sangue" return nothing relevant.
- **JP**: "trt" returns nothing relevant. The market's framing is **男性更年期 / LOH症候群** (male menopause) and **ホルモン補充療法** (Trough #12), plus "ホルモン補充" (Trough #2), "TRT 記録" (Trough #5), "テストステロン注射" (Trough #8), "ホルモン療法" (Trough #10). The leading competitor title pattern is "テストステロン注射記録・男性ホルモン". 血液検査 has no competition.
- **KR**: "trt" returns 1 relevant app. "테스토스테론" (Trough #11), "남성호르몬" (#4), "남성호르몬 주사" (#3), "테스토스테론 주사" (#9). "주사 기록" and "주사" are dominated by diet-injection (GLP-1) apps. 남성 갱년기 (male menopause) is the local framing, the same as in Japan.
- **NL**: "trt" returns nothing relevant. "testosteron" (24 relevant), "testosteron injectie" (Trough #11), "bloedonderzoek" (#14), "peptiden" (#15) and "bloedwaarden" (TRT apps) are what people search. "prik" is GLP-1 "afvalprik" territory.
- **PL**: "zastrzyki" (Trough #9, 24 relevant), "iniekcje" (#4), "badania krwi" (#11), "peptydy" (#15). "terapia hormonalna" and "terapia testosteronem" have almost no results.
- **BR**: "trt" collides with the labour courts (TRT = Tribunal Regional do Trabalho), but "trt tracker" works (Trough #9). "reposição hormonal" and "reposição de testosterona" return the TRT apps that exist in Brazil (the local term). "exames de sangue" has no competition. GLP-1 terms are very saturated (OzemPro has about 16k ratings). "Deposteron" is a drug brand and was skipped.
- **SE**: "trt" returns nothing relevant. "testosteron" (23), "blodprov" (Trough #17), "hormonbehandling" and "testosteronbehandling" (few but exact results). "spruta" is used, often for GLP-1 "bantningsspruta" apps. "hormonterapi" returns 0 results.

## Positioning differences

- **"TRT" is an English/US search term.** In DE, FR, NL, SE, JP, MX and IT, "trt" on its own returns few or no relevant apps, so those names lead with the native **"Testosteron/Testostérone/Testosterona/テストステロン/테스토스테론"** and keep "TRT" second for recognition. The en-GB/en-US backup indexing also covers "trt" there.
- **JP and KR** frame TRT as treatment for 男性更年期 / 남성 갱년기 (male menopause, LOH) and as 男性ホルモン補充 / 남성호르몬 (male hormone replacement). These terms go in the keywords and the audience line, with no outcome claims.
- **BR** says "reposição hormonal" (hormone replacement), not "terapia". It is in the subtitle.
- **UK/AU** say "jab", "bloods" and "blood test"; **AU** uses "pathology". **US/CA** say "shot" and "bloodwork".
- **"HRT"** means menopause or trans HRT in the US; in the UK, "male HRT" does surface TRT apps. So "hrt"+"male" are in en-GB only.

## Chosen metadata (1.4.0)

| Locale | Name | Subtitle | Keywords |
|---|---|---|---|
| en-US | Trough: TRT & Testosterone Log | Injection Tracker & Bloodwork | `peptide,hormone,shot,dose,levels,labs,glp-1,estradiol,e2,cypionate,enanthate,reminder,syringe,pk,men` |
| en-GB | Trough: TRT & Testosterone Log | Injection & Blood Test Tracker | `peptide,hormone,jab,shot,dose,levels,bloods,results,glp-1,oestradiol,e2,hrt,male,reminder,diary` |
| en-AU | Trough: TRT & Testosterone Log | Injection & Blood Test Tracker | `pathology,labs,syringe,needle,schedule,calendar,site,rotation,cypionate,enanthate,estradiol,pk,men` |
| en-CA | Trough: TRT & Testosterone Log | Injection Tracker & Bloodwork | `peptide,hormone,shot,dose,levels,labs,glp-1,estradiol,e2,reminder,pk,suivi,sang,analyse,hormonal` |
| de-DE | Trough: Testosteron & TRT | Injektion & Blutwerte tracken | `spritze,tagebuch,tracker,hormon,hormontherapie,peptid,glp-1,östradiol,e2,dosis,erinnerung,spiegel` |
| fr-FR | Trough : Testostérone & TRT | Injections & bilan sanguin | `suivi,hormone,traitement,hormonal,analyse,sang,peptide,glp-1,estradiol,e2,rappel,seringue,dose,taux` |
| es-ES | Trough: Testosterona y TRT | Inyecciones y analíticas | `terapia,hormonal,análisis,sangre,péptido,glp-1,estradiol,e2,recordatorio,dosis,niveles,pinchazo` |
| es-MX | Trough: Testosterona y TRT | Control de inyecciones y labs | `terapia,hormonal,análisis,sangre,laboratorio,péptido,glp-1,estradiol,e2,recordatorio,jeringa,dosis` |
| it | Trough: Testosterone e TRT | Diario iniezioni e analisi | `terapia,ormonale,ormoni,esami,sangue,peptidi,glp-1,estradiolo,e2,promemoria,siringa,dosaggio,livelli` |
| pt-BR | Trough: Testosterona e TRT | Reposição hormonal e injeções | `exames,sangue,peptídeo,glp-1,estradiol,e2,lembrete,seringa,aplicação,dose,níveis,hormônio,terapia` |
| nl-NL | Trough: Testosteron & TRT | Injecties en bloedwaarden | `hormoon,hormoontherapie,bloedonderzoek,bloedtest,peptide,glp-1,oestradiol,e2,herinnering,spuit,dosis` |
| pl | Trough: Testosteron i TRT | Zastrzyki i badania krwi | `iniekcje,testosteronu,hormony,hormonalna,peptydy,glp-1,estradiol,e2,przypomnienie,strzykawka,dawka` |
| sv | Trough: Testosteron & TRT | Injektioner och blodprov | `spruta,hormon,hormonbehandling,testosteronbehandling,peptid,glp-1,östradiol,e2,påminnelse,dos,logg` |
| ja | Trough：テストステロン注射記録 | TRT・男性ホルモン補充・血液検査 | `男性更年期,LOH症候群,ホルモン療法,ホルモン補充療法,ペプチド,GLP-1,エストラジオール,血中濃度,薬物動態,PK,リマインダー,トラッカー,日記,検査結果,管理,スケジュール,カレンダー` |
| ko | Trough: 테스토스테론 주사 기록 | TRT·남성호르몬·혈액검사 관리 | `남성갱년기,갱년기,호르몬,호르몬치료,호르몬보충,보충요법,펩타이드,GLP-1,에스트라디올,E2,혈중농도,PK,알림,트래커,다이어리,일지,검사결과,수치,캘린더` |

Rules we applied: names and subtitles ≤30 characters, keywords ≤100 characters (counted as characters; if App Store Connect counts ja/ko keywords in bytes, trim the tail items), no spaces after commas, no word repeated from that locale's name or subtitle, singular forms, no competitor or trademark drug brands, no "best/#1", no outcome claims ("boost", "optimize"). The description never states a trial length (see open issues).

## Open issues found during research

1. **Trial length is inconsistent.** The brief says 7-day, `Trough.storekit` has `P3D` (3 days) for both products, and the app strings mix "7-day" (`paywall.startTrialFull`, `pro.trialIncluded`) with "3-day" (`paywall.trialBadge`, `onboarding.trialLegal`). Old store copy said 3-day. The new store copy says "free trial for eligible new subscribers" and gives no number of days. Confirm the real offer in App Store Connect and fix the in-app strings.
2. **Rank, badge and gamification strings aren't localized in-app yet** (no `rank.cover.*` keys in any `.lproj`). The store copy uses native tier names (Papier→Diamant, Papel→Diamante, ペーパー→ダイヤモンド…). Localize them in the app before release so the store and the app match.
3. `pt-BR.lproj` has `"tab.injections" = "Injecoes"`, which is missing its accents (should be "Injeções").
4. Consider adding an **fr-CA** localization (Canada indexes it).

## Weekly checkup routine

Re-run the queries (the script is below) and compare Trough's rank column for each market's core terms: us `trt`, `trt tracker`, `trt injection`, `testosterone`; gb `trt tracker`, `testosterone injection`; de `testosteron`, `testosteron injektion`; fr `testostérone`, `injection testostérone`; es `testosterona`; mx `testosterona`, `terapia testosterona`; it `testosterone iniezioni`; jp `テストステロン注射`, `ホルモン補充`; kr `테스토스테론`, `남성호르몬`; nl `testosteron injectie`; pl `zastrzyki`; br `trt tracker`, `reposição hormonal`; se `testosteron`, `blodprov`.

```python
# research.py (abridged): for each (country, term): GET itunes.apple.com/search?term=&country=&entity=software&limit=25
# relevant = genre in {Health & Fitness, Medical, Lifestyle, Productivity, Utilities, Reference}
#            and title/description contains a TRT/testosterone/peptide/hormone/injection stem (per language)
# trough_rank = position of trackId 6760955550; sleep 1.3s between calls, back off 5s × attempt on errors
```

## Raw results (top 25 per query, 24–25 Sep 2026)

### Storefront `us`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosterone replacement | 24 | 22 | – | Testosterone Boost - TestPeak (61); TRT Calculator: Testosterone (7); Testosterone Companion (0); Hims: Telehealth for Men (95510) |
| trt injection | 25 | 25 | 13 | Himcules: TRT Injection Log (10); TRT Tracker: Injections log (32); Peptide & TRT Tracker: OptiPin (168); Vialora: TRT Injection Log (0) |
| testosterone log | 25 | 20 | – | TRT Tracker: Testosterone Log (3); TRT Tracker: Log Testosterone (0); Himcules: TRT Injection Log (10); TRT Vault Testosterone Tracker (1) |
| hormone therapy men | 25 | 7 | – | Hims: Telehealth for Men (95510); Allara (1686); Mochi Health: Weight Loss (16067); Intermittent Fasting for Men (2493) |
| peptide injection | 25 | 24 | – | PeptidePal – Peptide Tracker (4698); Peptide Injection Tracker (1); Peptide Tracker & Calculator (543); Injectly (416) |
| injection reminder | 23 | 13 | – | MEDS: Pill & Injection Tracker (475); Injection Tracker & Reminder (7); Injection Tracker: Dose & Log (10); Injectly (416) |
| trt | 25 | 8 | 15 | TRT Tracker: Injections log (32); Peptide & TRT Tracker: OptiPin (168); Anabolic Steroid & TRT Tracker (74); My TRT App (1) |
| trt tracker | 23 | 22 | 21 | TRT Tracker: Injections log (32); Peptide & TRT Tracker: OptiPin (168); Anabolic Steroid & TRT Tracker (74); TTracker: TRT Tracker (2) |
| testosterone | 25 | 21 | – | TRT Calculator: Testosterone (7); TestoMax: Boost Testosterone (5); Testosterone Companion (0); Testosterone Boost - TestPeak (61) |
| testosterone tracker | 23 | 17 | – | Peptide & TRT Tracker: OptiPin (168); Testosterone Tracker: T-Boost (6); TRT Tracker: Testosterone Log (3); Anabolic Steroid & TRT Tracker (74) |
| injection tracker | 25 | 25 | – | Injectly (416); Injection Tracker & Reminder (7); Shotsy GLP-1 Tracker (32440); Injection Tracker: Dose & Log (10) |
| injection log | 25 | 23 | – | Injectly (416); MEDS: Pill & Injection Tracker (475); Drop: Injection Tracker (2); Peptide Tracker & Calculator (543) |
| shot tracker | 23 | 5 | – | Shotsy GLP-1 Tracker (32418); Klick: GLP-1 Shot Tracker (10); GLP-1 Companion: Shot Tracker (1); MeAgain: GLP-1 Tracker App (34412) |
| hormone tracker | 24 | 13 | – | Hormona: Period Tracker (754); Moody Month: Hormone Tracker (884); Stardust Period Tracker (117364); Lively - Period Tracker, Cycle (52037) |
| hrt tracker | 23 | 17 | – | HRTMe: HRT & Menopause Tracker (29); Attune: HRT Tracker (2); Health & Her App (931); Trans Tracker (2) |
| peptide tracker | 25 | 25 | – | PeptidePal – Peptide Tracker (4698); Peptide Tracker Log & Reminder (2276); Pep AI: Peptide GLP-1 Tracker (3700); Peptide Tracker & Calculator (543) |
| peptide | 25 | 25 | – | PeptidePal – Peptide Tracker (4698); Pep AI: Peptide GLP-1 Tracker (3700); Peptide Tracker & Calculator (543); Peptide Tracker Log & Reminder (2276) |
| bloodwork | 20 | 5 | – | Medical Lab Tests (1141); Lab Test Values (318); Evolve: Bloodwork Insights (1); Laboratory Test Analyzer (4) |
| blood test tracker | 24 | 1 | – | BioSignal Blood Test Tracker (0) |
| lab results tracker | 25 | 7 | – | Laboratory Test Analyzer (4); Peptide Tracker Log & Reminder (2276); Clarity: Health & Lab Insights (18); Medical Lab Tests (1141) |
| glp-1 tracker | 25 | 24 | – | Shotsy GLP-1 Tracker (32418); MeAgain: GLP-1 Tracker App (34412); DreamMe: GLP-1 Tracker Pet (2890); JellyPal: GLP-1 Tracker (10) |
| testosterone injection | 25 | 23 | – | Himcules: TRT Injection Log (10); TRT Vault Testosterone Tracker (1); TRT Tracker: Log Testosterone (0); TRT Tracker: Testosterone Log (3) |
| testosterone levels | 25 | 22 | – | Buff - Manhood Testosterone (26); TestoCheck: Boost Testosterone (0); Testosterone+ : T-Tracker (0); Hims: Telehealth for Men (95510) |
| dose tracker | 23 | 16 | – | Dose: Peptide Tracker (92); DoseVault: Injection Tracker (0); Shotsy GLP-1 Tracker (32440); DoseMate: GLP-1 Tracker (0) |
| hormone | 24 | 17 | – | Moody Month: Hormone Tracker (884); Lively - Period Tracker, Cycle (52069); Hormona: Period Tracker (754); Stardust Period Tracker (117404) |
| estradiol | 23 | 13 | – | Mona - HRT journal (7); HRT Stats (0); Hormona: Period Tracker (754); Moody Month: Hormone Tracker (884) |
| hcg | 23 | 1 | – | Hormona: Period Tracker (754) |
| pinning | 23 | 0 | – | – |
| cypionate | 15 | 10 | – | Peptide & TRT Tracker: OptiPin (168); Regimen: Peptide Tracker GLP 1 (449); TRT Calculator: Testosterone (7); TRT Vault Testosterone Tracker (1) |
| enanthate | 7 | 7 | – | Peptide & TRT Tracker: OptiPin (168); Regimen: Peptide Tracker GLP 1 (449); TRT Calculator: Testosterone (7); TRT Vault Testosterone Tracker (1) |
| hormone replacement | 25 | 17 | – | Hormone Health Log (0); 28: Period Tracker & Health (5664); Balance - Menopause & Hormones (1122); Hormona: Period Tracker (754) |
| inyecciones | 23 | 19 | – | Jabby GLP-1 Medication Tracker (52); GLP-1 Logbook: Shot Tracker (0); Drop: Injection Tracker (2); GLP Flow: Shot Day Meals (6) |
| testosterona | 22 | 21 | – | TRT Tracker: Testosterone Log (3); Testosterone Tracker: TRT AI (0); TRT Calculator: Testosterone (7); TRT Tracker: Log Testosterone (0) |
| low t | 24 | 0 | – | – |
| site rotation | 24 | 2 | – | Zepbound & Mounjaro Tracker (3042); SiteCycle: Injection Tracker (3) |
| trough | 22 | 1 | 11 | Trough - TRT Tracker (2) |
| steroid tracker | 24 | 15 | – | Anabolic Steroid & TRT Tracker (74); Cycle: Anabolic & TRT Tracker (0); Peptide & TRT Tracker: OptiPin (168); Injectly (416) |
| cycle tracker men | 23 | 1 | – | Flux : Men Cycle Tracker (0) |

### Storefront `gb`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosterone replacement | 23 | 22 | – | TRT Tracker: Testosterone Log (0); TRT Calculator: Testosterone (0); STONE: Boost Testosterone (6); TestoMax: Boost Testosterone (0) |
| hrt men | 24 | 3 | – | PatchDay (1); HRTMe: HRT & Menopause Tracker (159); Muscle Charge: Men 40+ Fitness (81) |
| testosterone log | 25 | 20 | – | TRT Tracker: Testosterone Log (0); TRT Tracker: Log Testosterone (0); Himcules: TRT Injection Log (1); Testosterone Tracker: TRT AI (0) |
| male hrt | 24 | 12 | – | PatchDay (1); HRTMe: HRT & Menopause Tracker (159); HRT Stats (0); Anabolic Steroid & TRT Tracker (11) |
| trt | 23 | 11 | – | TRT Tracker: Injections log (3); My TRT App (0); PinPoint TRT (0); TRT Plus (4) |
| trt tracker | 25 | 24 | 22 | TRT Tracker: Injections log (3); Anabolic Steroid & TRT Tracker (11); Peptide Tracker & TRT: OptiPin (25); TRT Tracker: Testosterone Log (0) |
| testosterone | 25 | 25 | – | TestoMax: Boost Testosterone (0); TRT Calculator: Testosterone (0); Peptide Tracker & TRT: OptiPin (25); Buff - Manhood Testosterone (8) |
| injection tracker | 24 | 24 | – | Injection Tracker & Reminder (1); GLP1 Tracker - Shotsy (4142); Peptide Tracker & TRT: OptiPin (25); InjecTrack (2) |
| jab tracker | 25 | 20 | – | GLP1 Tracker - Shotsy (4142); JabTracker: GLP-1 Tracker (1); Vital: GLP-1 Jab Tracker (2); ShotLock: GLP-1 Jab Tracker (0) |
| hrt | 24 | 13 | – | HRTMe: HRT & Menopause Tracker (159); Balance - Hormones & Menopause (27269); Health & Her App (3380); PatchDay (1) |
| hrt tracker | 25 | 17 | – | HRTMe: HRT & Menopause Tracker (159); Balance - Hormones & Menopause (27269); Health & Her App (3380); SimpleHRT (1) |
| bloods | 21 | 0 | – | – |
| blood test | 22 | 0 | – | – |
| peptide | 25 | 24 | – | PeptidePal – Peptide Tracker (372); Peptidely - The Peptide Bible (0); GLP1 Tracker - Shotsy (4142); Pep AI: Peptide GLP-1 Tracker (109) |
| hormone tracker | 23 | 9 | – | Moody Month: Hormone Tracker (669); Stardust Period Tracker (13190); Hormona: Period Tracker (234); Balance - Hormones & Menopause (27269) |
| testosterone injection | 25 | 23 | – | Himcules: TRT Injection Log (1); TRT Tracker: Testosterone Log (0); TRT Tracker: Log Testosterone (0); TRT Calculator: Testosterone (0) |
| nebido | 4 | 0 | – | – |
| sustanon | 3 | 2 | – | Peptide Tracker & TRT: OptiPin (25); TRT Tracker: Dose & Bloodwork (0) |
| testogel | 7 | 3 | – | Peptide Tracker & TRT: OptiPin (25); Orchidometer (0); Testo Booster: TestoRise (0) |
| low testosterone | 23 | 20 | – | Testosterone Boost - TestPeak (3); Boost - Increase Testosterone (1); TRT Calculator: Testosterone (0); STONE: Boost Testosterone (6) |
| peptide tracker | 25 | 25 | – | Peptide Tracker Log & Reminder (81); GLP1 Tracker - Shotsy (4142); PeptidePal – Peptide Tracker (372); Peptide Tracker & Calculator (9) |
| injection log | 25 | 23 | – | Injectly (15); GLP-1 Tracker: Injections Log (0); TRT Tracker: Injections log (3); Peptide Tracker & Calculator (9) |

### Storefront `au`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| trt | 20 | 9 | – | TRT Plus (4); TRT Tracker: Injections log (1); Anabolic Steroid & TRT Tracker (8); TRT Tracker: Testosterone Log (0) |
| trt tracker | 25 | 25 | 22 | TRT Tracker: Injections log (1); Anabolic Steroid & TRT Tracker (8); Milligram - Peptide Tracker (290); Peptide & TRT Tracker: OptiPin (22) |
| testosterone | 25 | 25 | – | TestoMax: Boost Testosterone (1); TRT Tracker: Injections log (1); TRT Calculator: Testosterone (0); Testosterone Boost - TestPeak (2) |
| injection tracker | 24 | 24 | – | Shotsy - GLP-1 Tracker (1478); Injection Tracker & Reminder (1); Peptide & TRT Tracker: OptiPin (22); Injection Tracker: Dose & Log (0) |
| hrt | 24 | 12 | – | HRTMe: HRT & Menopause Tracker (12); SimpleHRT (0); HRT Stats (0); HRT-Recorder (0) |
| hormone tracker | 22 | 9 | – | Moody Month: Hormone Tracker (172); Lively - Period Tracker, Cycle (4719); Hormona: Period Tracker (38); Stardust Period Tracker (9755) |
| peptide | 25 | 25 | – | PeptidePal – Peptide Tracker (574); Peptide Tracker Log & Reminder (236); Shotsy - GLP-1 Tracker (1478); Peptidely - The Peptide Bible (0) |
| blood test | 23 | 0 | – | – |
| bloods | 23 | 0 | – | – |
| jab | 18 | 6 | – | Zepbound Tracker: Jab Journey (0); Jabby GLP-1 Medication Tracker (0); ShotLock: GLP-1 Jab Tracker (0); Shotsy - GLP-1 Tracker (1478) |
| reandron | 1 | 1 | – | Peptide & TRT Tracker: OptiPin (22) |
| testosterone injection | 25 | 23 | 19 | Himcules: TRT Injection Log (0); TRT Vault Testosterone Tracker (0); TRT Tracker: Testosterone Log (0); Dosely - Peptide Tracker (11) |
| peptide tracker | 25 | 25 | – | Peptide Tracker Log & Reminder (236); PeptidePal – Peptide Tracker (574); Shotsy - GLP-1 Tracker (1478); Milligram - Peptide Tracker (290) |

### Storefront `ca`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| trt | 23 | 7 | – | Peptide & TRT Tracker: OptiPin (23); TRT Plus (0); TRT Tracker: Injections log (4); Anabolic Steroid & TRT Tracker (4) |
| trt tracker | 25 | 24 | 22 | Peptide Tracker GLP 1: Regimen (32); TTracker: TRT Tracker (0); TRT Tracker: Injections log (4); TRT Tracker: Testosterone Log (0) |
| testosterone | 25 | 25 | – | TRT Tracker: Injections log (4); TRT Calculator: Testosterone (0); Testosterone Boost - TestPeak (3); MAX: Testosterone Booster (0) |
| injection tracker | 23 | 23 | – | Injection Tracker & Reminder (0); GLP-1 Tracker - Shotsy (2297); Peptide & TRT Tracker: OptiPin (23); MEDS: Pill & Injection Tracker (79) |
| hormone tracker | 24 | 9 | – | Stardust Period Tracker (12828); Moody Month: Hormone Tracker (256); Lively - Period Tracker, Cycle (6602); Hormona: Period Tracker (348) |
| hrt | 23 | 12 | – | HRT Stats (0); HRTMe: HRT & Menopause Tracker (10); HRT BT (0); HRT-Recorder (0) |
| peptide | 25 | 25 | – | PeptidePal – Peptide Tracker (443); Peptide Tracker Log & Reminder (156); Peptide Tracker & Calculator (55); GLP-1 Tracker - Shotsy (2297) |
| bloodwork | 20 | 7 | – | Evolve: Bloodwork Insights (1); Medical Lab Tests (173); Vytals: Bloodwork & Longevity (0); Seralog: TRT Bloodwork Tracker (0) |
| testostérone | 24 | 24 | – | TRT Calculator: Testosterone (0); TRT Tracker: Testosterone Log (0); STONE: Boost Testosterone (2); Primal - Testosterone Habits (0) |
| injection | 24 | 19 | – | MEDS: Pill & Injection Tracker (79); Drop: Injection Tracker (0); GLP-1 Tracker - Shotsy (2297); Njection App (0) |
| suivi hormonal | 23 | 11 | – | Lively - Period Tracker, Cycle (6602); Cycle Syncing Tracker - Phase (0); Solaia: Hormonal Balance (64); Moody Month: Hormone Tracker (256) |
| peptide tracker | 25 | 25 | – | Peptide Tracker Log & Reminder (156); Reta - Peptide Tracker (0); PeptidePal – Peptide Tracker (443); Peptide Tracker & Calculator (55) |
| blood test | 21 | 0 | – | – |

### Storefront `de`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosteron spritze | 10 | 10 | – | TRT Tracker: Testosteron (0); Testosteron Tracker: TRT AI (0); Halflife - Peptid & GLP-1 Log (1); PeptideTrack: Peptid Tracker (0) |
| testosteron injektion | 17 | 17 | 10 | TRT Tracker: Testosteron (0); Testosteron Tracker: TRT AI (0); TRT Tracker: Testosterone Log (0); Peptid Tracker & TRT / OptiPin (5) |
| testo | 17 | 0 | – | – |
| hormonersatz | 0 | 0 | – | – |
| blutbild | 22 | 0 | – | – |
| hormon | 22 | 12 | – | Hormona: Period Tracker (52); fitElle: Zyklus & Hormon-Guide (12); Health & Her App (44); Balance - Hormones & Menopause (74) |
| peptid | 25 | 24 | – | Mounjaro Tracker - Shotsy (1551); Bo: Peptide Tracker Calculator (17); Peptid-Rechner: PepFlow (16); Dosely - Peptide Tracker (2) |
| trt therapie | 10 | 10 | – | TRT Tracker: Testosterone Log (0); TRT Tracker: Testosteron (0); Injectly (25); Trace: Peptide & TRT Tracker (0) |
| spritzen | 22 | 11 | – | Mounjaro Tracker - Shotsy (1551); Medikamenten-Tracker & Spritze (1); Haftra: GLP-1 Spritzen-Tracker (0); GLP-1 Spritzen-Tracker (0) |
| spritzentagebuch | 1 | 1 | – | TRT Tracker: Dosis & Blutwerte (0) |
| trt | 24 | 1 | – | TRT Thailand (0) |
| testosteron | 25 | 23 | – | TRT Tracker: Testosterone Log (0); TRT Tracker: Injections log (0); Peptid Tracker & TRT / OptiPin (5); Testosteron Tracker: TRT AI (0) |
| testosteron tracker | 23 | 22 | – | Testosteron Tracker: TRT AI (0); TRT Tracker: Testosterone Log (0); TRT Tracker: Testosteron (0); Mojo: Testosterone Tracker (1) |
| testosterontherapie | 0 | 0 | – | – |
| hormontherapie | 9 | 5 | – | Praxis Dres. Harnisch (4); Resilience Onco (1); TRT Tracker: Testosterone Log (0); Trace: Peptide & TRT Tracker (0) |
| hormonersatztherapie | 2 | 1 | – | TALIA: Wechseljahre & HRT (1) |
| spritze | 24 | 13 | – | Medikamenten-Tracker & Spritze (1); GLP1 Tracker Spritze & Gewicht (0); GLP-1 Spritze Abnehmen Gewicht (0); Spritzmittel & Tank-Rechner (0) |
| spritzen tracker | 25 | 25 | – | Haftra: GLP-1 Spritzen-Tracker (0); Mounjaro Tracker - Shotsy (1551); Bo: Peptide Tracker Calculator (17); GLP-1 Spritzen-Tracker (0) |
| injektion | 24 | 22 | – | Peptide Log: Injektionen (0); Mounjaro Tracker - Shotsy (1551); Medikamenten-Tracker & Spritze (1); Peptid-Tracker: Zyklus (6) |
| injektionstagebuch | 3 | 3 | – | Injektionstagebuch - GLP-1 (0); GLP.AI - GLP-1 Tracker (0); Shotlog - Injection Tracker (0) |
| blutwerte | 23 | 2 | – | Gesundheit Tracker & Biomarker (1); ThyreoCal (25) |
| laborwerte | 21 | 1 | – | LaboRef (1) |
| peptide | 25 | 24 | – | Peptide Tracker & Calculator (14); Injectly (25); Mounjaro Tracker - Shotsy (1551); Peptid-Tracker: Zyklus (6) |
| hormone | 24 | 17 | – | Hormona: Period Tracker (52); Health & Her App (44); Stardust Period Tracker (2754); Solaia: Hormonbalance (9) |
| glp-1 | 25 | 22 | – | Mounjaro Tracker - Shotsy (1551); Glowise: GLP-1 Tracker&Journal (58); GLP-1 Tracker: Pep (4); MeAgain: GLP-1 Tracker App (26) |
| abnehmspritze | 25 | 24 | – | GLP 1 Mounjaro Tracker: Velto (28); AMITA – Abnehmspritze Tracker (38); Mounjaro Tracker: Mingo GLP-1 (9); Mounjaro: GLP-1 Tracker AI (16) |
| medikamenten erinnerung | 24 | 2 | – | Pillen Erinnerung: Recure (0); Tabletten Erinnerung - Pillen (2) |
| nebido | 1 | 1 | – | Peptid Tracker & TRT / OptiPin (5) |
| testogel | 1 | 1 | – | Peptid Tracker & TRT / OptiPin (5) |
| hormon tracker | 25 | 13 | – | Moody Month: Hormone Tracker (19); HeyTimi: PCOS Hormon-Tracker (0); Zyklus Tracker - Phase (0); Hormona: Period Tracker (52) |
| trt tracker | 25 | 23 | – | TRT Tracker: Testosterone Log (0); TRT Tracker: Injections log (0); Peptid Tracker & TRT / OptiPin (5); Anabolic Steroid & TRT Tracker (1) |

### Storefront `es`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosterona inyectable | 0 | 0 | – | – |
| inyección testosterona | 17 | 17 | 11 | Testosterona Tracker: TRT AI (0); Péptidos TRT Tracker / OptiPin (2); Péptidos Tracker: TRT y GLP-1 (0); PeptideTrack: Péptidos (0) |
| hormona | 24 | 6 | – | Hormona: Calendario Menstrual (22); Hormona Vida (0); GroAssist ES (0); Testosterona Tracker: TRT AI (0) |
| trt testosterona | 23 | 23 | 18 | Testosterona Tracker: TRT AI (0); Péptidos TRT Tracker / OptiPin (2); Péptidos Tracker: TRT y GLP-1 (0); Injectly (2) |
| analíticas | 21 | 1 | – | TRT: Dosis y Analíticas (0) |
| péptido | 25 | 22 | 24 | Peptido: AI Peptide Tracker (0); Pepture: Rastreador de Péptido (0); PeptideMax: Control Péptidos (0); Control de péptidos: PeptiPal (0) |
| trt | 19 | 3 | – | Péptidos TRT Tracker / OptiPin (2); JTe (0); Anabolic Steroid & TRT Tracker (0) |
| testosterona | 22 | 18 | 16 | Testosterona Tracker: TRT AI (0); Dr. Testo: Eleva Testosterona (0); TRT Tracker: Testosterone Log (0); TRT Tracker: Testosterona (0) |
| terapia testosterona | 4 | 4 | 4 | Testosterona Tracker: TRT AI (0); TRT Tracker: Testosterona (0); TRT Tracker: Testosterone Log (0); Trough - TRT Tracker (0) |
| terapia hormonal | 9 | 6 | 7 | Criterios Elegibilidad THM (5); Testosterona Tracker: TRT AI (0); TRT Tracker: Testosterone Log (0); Estabiliza: HRT menopausia (0) |
| inyecciones | 19 | 14 | – | Drop: Rastreador de inyección (0); MEDS: Pastillas e Inyecciones (5); Andaluza Inyección (3); GLP1 Tracker Inyección y peso (0) |
| registro inyecciones | 25 | 22 | – | MEDS: Pastillas e Inyecciones (5); Mounjaro registro: Jabalog (0); Caliper: Registro GLP-1 (0); EvenDose: Inyección GLP-1 (0) |
| hormonas | 23 | 15 | – | Nura: Bienestar Hormonal (2); Moody Month: Hormone Tracker (16); Solaia: Equilibrio hormonal (7); Hormona: Calendario Menstrual (22) |
| análisis de sangre | 22 | 2 | – | PeptideTrack: Péptidos (0); Testosterona Tracker: TRT AI (0) |
| analítica | 22 | 0 | – | – |
| péptidos | 25 | 23 | – | Péptidos: Calculadora y TRT (0); Tracker GLP-1 y péptidos (0); Péptidos TRT Tracker / OptiPin (2); Calculadora péptidos: PepFlow (5) |
| glp-1 | 25 | 22 | – | Glowise: Tracker GLP-1 &diario (192); Shotsy - Rastreador GLP-1 (335); Rastreador GLP-1 - GLPTracker (4); GLP Diet: GLP-1 Weight Loss (72) |
| trt tracker | 24 | 23 | – | Péptidos TRT Tracker / OptiPin (2); TRT: Dosis y Analíticas (0); Anabolic Steroid & TRT Tracker (0); Regimen: Peptide Calculator (2) |
| control inyecciones | 25 | 23 | – | MounjaGO: control GLP-1 (0); Shotlee: Control de peso GLP-1 (0); Tracky: Control de GLP-1 (18); Poky: GLP-1 Peptide Tracker (28) |
| hormonas masculinas | 3 | 2 | – | TestoCheck — Sube tu Testo (0); TestMax - Become Manly (0) |

### Storefront `mx`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosterona inyectable | 0 | 0 | – | – |
| inyección testosterona | 18 | 17 | 14 | TRT Tracker: Testosterona (1); Péptidos TRT Tracker / OptiPin (0); PeptideTrack: Péptidos (0); Péptidos, TRT y GLP-1: Anre (0) |
| hormona | 23 | 11 | – | Hormona: Calendario Menstrual (16); Hormona Vida (0); Prevena: Predicción Migraña (0); Growzen® Buddy (0) |
| terapia testosterona | 2 | 2 | 2 | TRT Tracker: Testosterona (1); Trough - TRT Tracker (0) |
| laboratorios | 25 | 0 | – | – |
| péptido | 24 | 19 | – | Halflife - Péptido & GLP-1 Log (0); Control de péptidos: PeptiPal (0); PepDose: Calculadora Péptido (0); Peptido: AI Peptide Tracker (0) |
| trt | 14 | 0 | – | – |
| testosterona | 24 | 19 | – | TestoMax: Boost Testosterone (1); Testosterona Tracker: TRT AI (0); Dr. Testo: Eleva Testosterona (0); Testosterone Calculator Pro (0) |
| terapia hormonal | 5 | 3 | 4 | Criterios Elegibilidad THM (0); TRT Tracker: Testosterona (1); Trough - TRT Tracker (0) |
| inyecciones | 24 | 22 | – | Inyecciones GLP-1: Jabby (1); GLP-1 Logbook: Inyecciones (0); Solane: Control de Inyecciones (0); Drop: Rastreador de inyección (0) |
| hormonas | 23 | 21 | – | Moody Month: Hormone Tracker (10); Hormona: Calendario Menstrual (16); Balance: salud hormonal (14); Hambre y Hormonas (0) |
| análisis de sangre | 22 | 1 | – | PeptideTrack: Péptidos (0) |
| estudios de laboratorio | 20 | 0 | – | – |
| péptidos | 25 | 21 | – | Tracker GLP-1 y péptidos (1); PeptPro: Rastreador Péptidos (0); Control de péptidos: PeptiPal (0); Calculadora péptidos: PepFlow (9) |
| glp-1 | 25 | 21 | – | Capydose: Control GLP-1 (3); Glowise: Tracker GLP-1 &diario (2560); Shotsy - Rastreador GLP-1 (499); Monju: Adelgazar con GLP-1 (677) |
| trt tracker | 25 | 23 | – | TRT Tracker: Testosterona (1); TRT Tracker: Injections log (0); TRT Tracker: Dose & Bloodwork (0); Péptidos TRT Tracker / OptiPin (0) |
| reemplazo hormonal | 0 | 0 | – | – |
| ozempic | 25 | 23 | – | Shotsy - Rastreador GLP-1 (499); OzemPro: Perder peso con GLP-1 (372); Mounjaro Rastreador: GLP AI (428); Gala GLP-1 Tracker (30) |
| registro inyecciones | 25 | 23 | – | GLP1: Registro de Inyección (0); Inyecciones GLP-1: Jabby (1); Registro de péptidos - PepOn (0); Dosi: Rastreador GLP-1 (14) |
| testosterone | 25 | 24 | – | TRT Calculator: Testosterone (0); Buff - Manhood Testosterone (0); Testosterone Calculator Pro (0); TestoMax: Boost Testosterone (1) |

### Storefront `fr`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| injection testostérone | 25 | 24 | 19 | Testostérone Tracker: TRT AI (0); Dosely - Peptide Tracker (1); TRT Tracker: Testostérone (0); Injectly (0) |
| testo | 16 | 0 | – | – |
| hormone | 25 | 17 | – | Solaia: Équilibre hormonal (2472); Moody Month: Hormone Tracker (10); Hormona: Period Tracker (18); Symptive: Hormone Health (0) |
| traitement testostérone | 4 | 4 | – | TRT Tracker: Testosterone Log (0); Mon parcours trans (2); Cystra : symptômes du SOPK (0); Solane : Suivi d'Injections (0) |
| bilan hormonal | 8 | 6 | – | Kynox - Suivi de cure santé (3); Testostérone Tracker: TRT AI (0); Calibrum: TRT Peptide Tracker (0); TRT Tracker: Testostérone (0) |
| peptide | 25 | 24 | – | Shotsy – Outil de suivi GLP-1 (581); Peptide Calculator: PepCalc (0); Peptide Tracker & Calculator (1); Peptidely - The Peptide Bible (0) |
| piqure | 22 | 12 | – | Bouton & Piqûre: Moustique (0); Piqûre de rappel (2); GLP-1 Tracker: piqûre & pilule (1); BiteCheck: Piqûres Insectes (0) |
| trt | 23 | 0 | – | – |
| testostérone | 25 | 22 | – | Buff - Testostérone Masculin (124); Primal - Testosterone Habits (9); Suivi peptides TRT / OptiPin (1); TRT Tracker: Testostérone (0) |
| testosterone | 25 | 24 | – | Buff - Testostérone Masculin (124); Primal - Testosterone Habits (9); TRT Calculator: Testosterone (0); Suivi peptides TRT / OptiPin (1) |
| traitement hormonal | 10 | 6 | – | Ainoha Périménopause Ménopause (16); TALIA: Suivi Ménopause & THM (0); Mon parcours trans (2); TRT Tracker: Testosterone Log (0) |
| hormones | 25 | 18 | – | Solaia: Équilibre hormonal (2472); Stardust Cycle Tracker (1009); Hormona: Period Tracker (18); Balance - Hormones & Menopause (89) |
| injection | 24 | 19 | – | GLP1Suivi – Injections & poids (373); Shotsy – Outil de suivi GLP-1 (581); Dosley : Suivi Injection (1); Njection App (1) |
| suivi injection | 25 | 25 | – | GLP1Suivi – Injections & poids (373); Dosley : Suivi Injection (1); GLP-1 Log : Suivi Injection (0); Mounjaro: Outil de suivi GLP-1 (210) |
| piqûre | 22 | 13 | – | Bouton & Piqûre: Moustique (0); TickBug : Tique & Piqûre (0); Piqûre de rappel (2); GLP-1 Tracker: piqûre & pilule (1) |
| analyse de sang | 23 | 3 | – | Testostérone Tracker: TRT AI (0); PeptideTrack : peptides (0); Santé Tracker & Biomarqueurs (0) |
| bilan sanguin | 22 | 4 | – | TRT : Doses & Bilan Sanguin (0); Testostérone Tracker: TRT AI (0); TRT Tracker: Testostérone (0); Calibrum: TRT Peptide Tracker (0) |
| prise de sang | 20 | 2 | – | Santé Tracker & Biomarqueurs (0); Testostérone Tracker: TRT AI (0) |
| peptides | 25 | 24 | – | Calculateur peptides: PepFlow (5); Peptides Calculator (0); Peptide Calculator: PepCalc (0); Pep AI: Peptide GLP-1 Tracker (6) |
| glp-1 | 25 | 21 | – | Shotsy – Outil de suivi GLP-1 (581); OzemPro : Suivi du GLP-1 (33); Mounjaro Tracker: Mingo GLP-1 (209); GLP-1 Companion: Shot Tracker (0) |
| trt tracker | 24 | 22 | – | TRT Tracker: Testostérone (0); TRT Tracker: Injections log (0); TRT : Doses & Bilan Sanguin (0); Suivi peptides TRT / OptiPin (1) |
| hormonothérapie | 3 | 2 | – | RESIL.IO Health (1); TRT : Doses & Bilan Sanguin (0) |
| suivi hormonal | 25 | 9 | – | Suivi Cycle Hormonal - Phase (0); Nutrilogie / Cycle Syncing (4); Suivi Post-partum (0); TALIA: Suivi Ménopause & THM (0) |

### Storefront `it`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosterone iniezioni | 4 | 4 | 4 | Peptidi Tracker: TRT e GLP-1 (0); TRT Tracker: Testosterone (0); StackTrackr: Peptidi e TRT (0); Trough - TRT Tracker (0) |
| iniezione | 24 | 23 | – | GLP1 Tracker Iniezione e peso (0); Drop: Tracciatore di iniezione (1); GLP-1: Peso e Iniezione (0); Medicinali e Iniezioni Tracker (1) |
| ormone | 22 | 1 | – | FIVET Diario: PMA Fecondazione (0) |
| esami | 23 | 0 | – | – |
| sangue | 22 | 0 | – | – |
| peptide | 25 | 24 | – | Peptide Calculator: PepCalc (0); Peptide Tracker & Calculator (0); Shotsy – Tracker GLP-1 (197); Pep AI: Peptide GLP-1 Tracker (3) |
| terapia | 24 | 0 | – | – |
| trt | 21 | 3 | – | Peptide & TRT Tracker: OptiPin (0); TRT Tracker: Injections log (0); My TRT App (0) |
| testosterone | 25 | 24 | – | TestoMax: Boost Testosterone (0); Testosterone Boost - TestPeak (1); Ritual: Testo reset in 90 days (1); TRT Calculator: Testosterone (0) |
| terapia ormonale | 6 | 3 | – | Testosterone Tracker: TRT AI (0); TRT Tracker: Testosterone Log (0); TRT Tracker: Testosterone (0) |
| terapia testosterone | 4 | 4 | 4 | Testosterone Tracker: TRT AI (0); TRT Tracker: Testosterone Log (0); TRT Tracker: Testosterone (0); Trough - TRT Tracker (0) |
| iniezioni | 25 | 23 | – | Medicinali e Iniezioni Tracker (1); Dosio - Iniezioni GLP-1 (0); EvenDose: Iniezioni GLP-1 (0); Peptide Log: Diario Iniezioni (0) |
| punture | 24 | 6 | – | GLP-1 Punture per Dimagrire (0); GLP-1 Tracker: puntura,pillola (0); GLP-1 Tracker: Diario Puntura (0); FIVET Diario: PMA Fecondazione (0) |
| ormoni | 24 | 1 | – | FIVET Diario: PMA Fecondazione (0) |
| esami del sangue | 24 | 1 | – | CRS Tessera sanitaria (44) |
| analisi del sangue | 24 | 0 | – | – |
| peptidi | 25 | 24 | – | Calcolatore Peptidi PepFlow (5); Calcolatore Peptidi + (1); PepMod: Tracker di Peptidi (16); Vital: GLP-1 Peptidi Log (1) |
| glp-1 | 25 | 22 | – | Shotsy – Tracker GLP-1 (197); Mounjaro Tracker: Mingo GLP-1 (271); La Mia Penna GLP-1 Tracker (47); Lithe: Peso GLP-1 Tracker (1) |
| trt tracker | 24 | 22 | – | TRT Tracker: Dose & Bloodwork (0); TRT Tracker: Injections log (0); TRT Tracker: Testosterone (0); Peptide & TRT Tracker: OptiPin (0) |
| diario iniezioni | 25 | 25 | – | Diario Iniezioni - GLP-1 (0); Peptide Log: Diario Iniezioni (0); Shotlee: Diario peso GLP-1 (0); Monitoraggio GLP-1: Jilpy (47) |
| terapia sostitutiva | 0 | 0 | – | – |

### Storefront `jp`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| テストステロン注射 | 13 | 13 | 8 | テストステロン注射記録・男性ホルモン: TRT AI (0); Vialora：TRT注射記録 (0); ペプチド記録 TRT・GLP-1注射 (0); Peptide Tracker - PeptideKit (0) |
| テストステロン 記録 | 20 | 16 | 14 | ダイエットアプリOWN.宅トレとカロリー&PFC管理で健康に (720); Testron -テストロン- / 仲間と筋トレの記録を共有 (3); テストステロン注射記録・男性ホルモン: TRT AI (0); HRT AI: 更年期・閉経・ホルモン記録 (0) |
| TRT 記録 | 20 | 20 | 5 | テストステロン注射記録・男性ホルモン: TRT AI (0); Vialora：TRT注射記録 (0); ペプチド記録 TRT・GLP-1注射 (0); Trace: Peptide & TRT Tracker (0) |
| 男性ホルモン 注射 | 2 | 2 | – | テストステロン注射記録・男性ホルモン: TRT AI (0); TRT Tracker: Testosterone Log (0) |
| ホルモン補充 | 14 | 10 | 2 | HRT AI: 更年期・閉経・ホルモン記録 (0); Trough - TRT Tracker (0); Trace: Peptide & TRT Tracker (0); ホットフラッシュ記録 (0) |
| 注射記録 | 24 | 22 | – | GLP-1・ペプチド注射記録 (0); Dosio - GLP-1注射記録 (0); Shotsy - GLP-1注射の追跡アプリ (46); めろん日記- 成長ホルモン治療服薬管理アプリ (24) |
| エナント酸 | 0 | 0 | – | – |
| AGA | 25 | 0 | – | – |
| trt | 24 | 0 | – | – |
| テストステロン | 24 | 15 | – | ダイエットアプリOWN.宅トレとカロリー&PFC管理で健康に (720); テストステロンメーター｜男磨き習慣アプリ (1); TestoCheck — 男性力を高める (0); 禁欲カウンター｜Zen Reboot (4) |
| 男性ホルモン | 23 | 7 | – | ソフィBe - 生理＆体調管理アプリ・月経周期＆妊活サポート (18300); テストステロン注射記録・男性ホルモン: TRT AI (0); TestoCheck — 男性力を高める (0); ホルモン焼道場蔵 (20) |
| ホルモン補充療法 | 13 | 9 | 12 | HRT AI: 更年期・閉経・ホルモン記録 (0); ホットフラッシュ記録 (0); Attune：HRT記録 (0); TRT Tracker: Testosterone Log (0) |
| ホルモン | 25 | 3 | – | ソフィBe - 生理＆体調管理アプリ・月経周期＆妊活サポート (18300); ホルモン焼道場蔵 (20); 幸せホルモン分析 (1) |
| 注射 | 23 | 4 | – | Shotsy - GLP-1注射の追跡アプリ (46); 予防接種スケジューラー (2315); お薬リマインダー：服薬記録と自己注射管理 (1); Drop: 注射追跡装置 (0) |
| 注射 記録 | 23 | 22 | – | Dosio - GLP-1注射記録 (0); ゼップバウンド注射記録：Jabalog (0); お薬リマインダー：服薬記録と自己注射管理 (1); GLP-1 ダイエット注射 体重記録 (0) |
| 血液検査 | 25 | 0 | – | – |
| 検査結果 | 23 | 0 | – | – |
| ペプチド | 25 | 23 | – | ペプチド計算機 PepFlow (1); PeptideTrack ペプチド記録 (1); GLP-1ペプチド記録: Glipath (0); Myo: GLP-1 & ペプチド記録 (0) |
| glp-1 | 25 | 23 | – | Shotsy - GLP-1注射の追跡アプリ (46); GLP-1トラッカー - GLPTracker (0); Lithe: GLP-1体重・服薬記録 (1); Glowise：GLP-1トラッカー＆日記 (1) |
| 更年期 男性 | 11 | 3 | – | TestoCheck — 男性力を高める (0); テストステロン注射記録・男性ホルモン: TRT AI (0); TRT Tracker: Testosterone Log (0) |
| 服薬管理 | 24 | 0 | – | – |
| お薬手帳 | 19 | 0 | – | – |
| 男性更年期 | 12 | 3 | – | テストステロン注射記録・男性ホルモン: TRT AI (0); TestoCheck — 男性力を高める (0); TRT Tracker: Testosterone Log (0) |
| ホルモン療法 | 19 | 14 | 10 | テストステロン注射記録・男性ホルモン: TRT AI (0); HRT AI: 更年期・閉経・ホルモン記録 (0); Endometriosis Tracker (0); emodi（エモディ）自己分析ができるジャーナリングアプリ (17) |

### Storefront `kr`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| 테스토스테론 주사 | 13 | 13 | 9 | 남성호르몬 테스토스테론 주사: TRT AI (0); Vialora: TRT 주사 기록 (0); Peptide Tracker: Regimen (0); Peptide Tracker - PeptideKit (0) |
| 남성호르몬 주사 | 3 | 3 | 3 | 남성호르몬 테스토스테론 주사: TRT AI (0); TRT Tracker: Testosterone Log (0); Trough - TRT Tracker (0) |
| 호르몬 주사 | 21 | 19 | 13 | 메디로그: 약 복용 주사 알림 (2); Halflife - 펩타이드 & GLP-1 호르몬 로그 (0); Vialora: TRT 주사 기록 (0); Folli – 난임·시험관 기록 (1) |
| 주사 트래커 | 25 | 25 | – | DoseWeek – 마운자로 위고비 주사기록 (6); 위고비 다이어트 주사 관리 - 샷시앱 (30); 메디로그: 약 복용 주사 알림 (2); Setva: GLP-1 주사 기록 (0) |
| 혈액 검사 | 25 | 2 | – | PeptideTrack 펩타이드 기록 (0); Calibrum: TRT Peptide Tracker (0) |
| 호르몬 보충 | 5 | 4 | – | Trace: Peptide & TRT Tracker (0); TestoCheck — 남성 호르몬 부스터 (0); 남성호르몬 테스토스테론 주사: TRT AI (0); Dr. Testo: 테스토스테론 높이세요 (0) |
| trt | 19 | 1 | – | TRT Tracker: Injections log (0) |
| 테스토스테론 | 20 | 19 | 11 | Dr. Testo: 테스토스테론 높이세요 (0); 남성호르몬 테스토스테론 주사: TRT AI (0); TRT Tracker: Testosterone Log (0); Peptide Tracker: Regimen (0) |
| 남성호르몬 | 5 | 5 | 4 | TestoCheck — 남성 호르몬 부스터 (0); 남성호르몬 테스토스테론 주사: TRT AI (0); TRT Tracker: Testosterone Log (0); Trough - TRT Tracker (0) |
| 호르몬 | 24 | 20 | – | 슈얼리 스마트 - 호르몬 건강 관리 (14); YuraCycle · 여성 호르몬 다이어리 (0); Hormona: Period Tracker (0); Moody Month: Hormone Tracker (1) |
| 호르몬 치료 | 17 | 11 | – | Bloom - 나의 호르몬 치료 다이어리 (2); 성장호르몬닷컴 (7); NoriTer - 노보 노디스크 (12); 갱년기 증상 트래커 - Meno (0) |
| 주사 | 23 | 15 | – | 삐약-1위 다이어트 주사 관리앱&기록,커뮤니티,병원약국 (325); 맞은자로: 주사 기록·체중 관리 (5); 홀가분 - GLP-1 주사 기록 (1); 위고비 다이어트 주사 관리 - 샷시앱 (30) |
| 주사 기록 | 25 | 21 | – | 삐약-1위 다이어트 주사 관리앱&기록,커뮤니티,병원약국 (325); 샷다 - 마운자로기록 위고비기록 다이어리 (29); trackly-다이어트 주사 및 건강 기록 (0); 맞은자로: 주사 기록·체중 관리 (5) |
| 혈액검사 | 25 | 1 | – | PeptideTrack 펩타이드 기록 (0) |
| 검사결과 | 24 | 0 | – | – |
| 펩타이드 | 25 | 25 | – | Stackr - 펩타이드 트래커 (0); PepMod: 펩타이드 트래커 (0); PeptideTrack 펩타이드 기록 (0); GLP-1 및 펩타이드 기록 (0) |
| glp-1 | 25 | 23 | – | MyDosey - 나만의 GLP-1 기록 (36); 삐약-1위 다이어트 주사 관리앱&기록,커뮤니티,병원약국 (325); 위고비 다이어트 주사 관리 - 샷시앱 (30); GLP-1 트래커 - GLPTracker (0) |
| 남성 갱년기 | 4 | 3 | – | TestoCheck — 남성 호르몬 부스터 (0); TRT Tracker: Testosterone Log (0); 남성호르몬 테스토스테론 주사: TRT AI (0) |
| 갱년기 | 25 | 9 | – | 갱년기 증상 트래커 - Meno (0); Lutara: 갱년기 트래커 (0); PeriTrack 갱년기 트래커 (2); 핫플래시 로거 - 갱년기 증상 기록 (0) |
| 복약 관리 | 25 | 1 | – | 약 알림 & 복약 관리: Recure (0) |
| 약 알림 | 24 | 1 | – | 약냥이: 복약 알림 (7) |

### Storefront `nl`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosteron injectie | 12 | 12 | 11 | Peptide TRT Tracker / OptiPin (2); Testosteron Tracker: TRT AI (0); Vialora: TRT-injectiedagboek (0); PeptideTrack: peptiden (0) |
| testosteron therapie | 10 | 9 | – | Testosteron Tracker: TRT AI (0); TRT Tracker: Testosterone Log (0); Vialora: TRT-injectiedagboek (0); TRT Lab (2) |
| hormonen | 25 | 18 | – | Menopause Journey (42); Hormona: Period Tracker (56); HormoonFestival (16); Moody Month: Hormone Tracker (29) |
| bloedtest | 13 | 2 | – | Gezondheid Tracker & markers (0); Calibrum: TRT Peptide Tracker (0) |
| peptide tracker | 24 | 24 | – | Peptide Tracker & Calculator (1); Reta - Peptide Tracker (0); Peptide Tracker (1); Shotsy: GLP-1 Tracker (265) |
| injectie tracker | 25 | 24 | – | Dosio - GLP-1 Injectietracker (3); Drop: Injectie-tracker (0); GLP1 Tracker Injectie & kg (0); MEDS: Injectie & Pil Tracker (4) |
| trt | 22 | 0 | – | – |
| testosteron | 25 | 24 | – | Testosterone Boost - TestPeak (0); Testosteron Tracker: TRT AI (0); TestoMax: Boost Testosterone (0); T-Score: Boost Testosterone (0) |
| hormoon | 23 | 9 | – | HormoonFestival (16); Cyclus Hormoon Tracker - Phase (0); Peptide Tracker - PeptideKit (0); SoFemale (5) |
| hormoontherapie | 3 | 0 | – | – |
| injectie | 24 | 20 | – | GLP1 Tracker Injectie & kg (0); MEDS: Injectie & Pil Tracker (4); Peptide Log: Injectiedagboek (0); GLP-1 Log: Injectie Dagboek (0) |
| injecties | 23 | 21 | – | MEDS: Injectie & Pil Tracker (4); GLP-1 Logbook: Injecties (0); GLP1 Tracker Injectie & kg (0); GLP-1 Injectie Tracker  Shotsy (0) |
| prik | 21 | 4 | – | Setva: GLP-1 Prik Tracker (0); GLP-1 Tracker: Prik & Eiwit (0); GLP-1 Afvalprik & Gewicht (0); GLP-1 Tracker: Afvalprik (0) |
| bloedwaarden | 22 | 6 | – | PeptideTrack: peptiden (0); Peptide TRT Tracker / OptiPin (2); Vialora: TRT-injectiedagboek (0); Pinned: Peptide Tracker & TRT (0) |
| bloedonderzoek | 18 | 3 | 14 | IVF Dagboek - IUI Behandeling (0); Testosteron Tracker: TRT AI (0); Trough - TRT Tracker (0) |
| peptide | 25 | 25 | – | Pep AI: Peptide GLP-1 Tracker (11); Shotsy: GLP-1 Tracker (265); Peptide Tracker & Calculator (1); Dose: Peptide Tracker (1) |
| peptiden | 17 | 16 | 15 | Vital: GLP-1 & Peptiden (0); PeptideTrack: peptiden (0); Peptide Library: Peptiden (0); GLP-1 & Peptiden: FitPilot (0) |
| glp-1 | 25 | 22 | – | Shotsy: GLP-1 Tracker (265); GLP-1 Companion: Shot Tracker (0); MeAgain: GLP-1 Tracker App (23); DreamMe: GLP-1 Tracker Pet (11) |
| trt tracker | 24 | 22 | – | TRT Tracker: Injections log (0); TRT Tracker: Testosteron (0); Anabolic Steroid & TRT Tracker (0); Peptide TRT Tracker / OptiPin (2) |
| medicijn herinnering | 24 | 4 | – | MedApp: Medicijn Herinnering (1290); Medicijn Herinnering: Dozzy (0); Pilly: medicijnherinnering (0); Doz: Medicijnherinnering (0) |

### Storefront `pl`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosteron zastrzyki | 2 | 2 | – | TRT Tracker: Testosterone Log (0); StackTrackr: Peptide Tracker (0) |
| zastrzyk | 24 | 19 | – | GLP-1 Weight Loss Tracker (0); GLP-1 Weight & Shot Tracker (0); GLPTrack: Shot & Protein Log (0); GLP1 Tracker Shot & Weight Log (1) |
| wyniki krwi | 13 | 2 | – | AB Lab Analyzer (0); Testosterone Tracker: TRT AI (0) |
| peptyd | 16 | 15 | – | Myo: GLP-1 & Peptide Tracker (0); Mounjaro GLP-1 Tracker: GLP AI (2); Halflife - Peptide & GLP-1 Log (0); Shotlee: GLP-1 Weight Tracker (0) |
| hormonalna | 5 | 2 | – | TestoCheck — Boost Your T (0); Calmgrid: Migraine Diary (0) |
| dziennik | 21 | 0 | – | – |
| trt | 18 | 1 | – | Anabolic Steroid & TRT Tracker (0) |
| testosteron | 24 | 23 | – | TRT Tracker: Testosterone Log (0); Testosterone Boost - TestPeak (0); TRT Calculator: Testosterone (0); Testosterone Calculator Pro (0) |
| terapia testosteronem | 1 | 1 | – | TRT Tracker: Testosterone Log (0) |
| terapia hormonalna | 1 | 0 | – | – |
| hormony | 24 | 2 | – | Hormony (0); Cycle Syncing Tracker - Phase (0) |
| zastrzyki | 25 | 24 | 9 | MEDS: Pill & Injection Tracker (3); Dose Compass: GLP-1 Jab Diary (0); Shotlee: GLP-1 Weight Tracker (0); Dosio: GLP-1 Shot Tracker (0) |
| iniekcje | 7 | 7 | 4 | MEDS: Pill & Injection Tracker (3); Peptide Tracker: Cycle (1); Kalori - calories & GLP-1 (0); Trough - TRT Tracker (0) |
| wyniki badań | 25 | 2 | – | TRT Tracker: Testosterone Log (0); AB Lab Analyzer (0) |
| badania krwi | 14 | 5 | 11 | Treat Diet App (3); IVF Diary: IUI Cycle Tracker (0); Testosterone Tracker: TRT AI (0); Trough - TRT Tracker (0) |
| peptydy | 21 | 20 | 15 | Merra: Med & Peptide Tracker (0); StackTrackr: Peptide Tracker (0); TrackPep: GLP-1 & Peptides (0); GLP-1 & Peptide: FitPilot (0) |
| glp-1 | 25 | 22 | – | MeAgain: GLP-1 Tracker App (9); GLP-1 Companion: Shot Tracker (0); GLP1 Tracker - Shotsy (165); GLP 1 Tracker - GLPTracker (1) |
| trt tracker | 23 | 21 | – | TRT Tracker: Testosterone Log (0); TRT Tracker: Dose & Bloodwork (0); Anabolic Steroid & TRT Tracker (0); Peptide Tracker & TRT: OptiPin (0) |
| przypomnienie leki | 24 | 5 | – | Medication & Pill Reminder (0); Medication Pill Reminder Dozzy (0); MEDS: Pill & Injection Tracker (3); Pill Reminder & Alarm: Recure (1) |
| hormon | 23 | 17 | – | Moody Month: Hormone Tracker (5); Balance - Hormones & Menopause (7); Solaia: Hormonal Balance (0); inne - hormone based minilab (3) |

### Storefront `br`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosterona injetável | 0 | 0 | – | – |
| reposição | 22 | 1 | – | Ciclo Hormonal - HorMonitor (0) |
| terapia hormonal | 5 | 3 | – | Elegibilidade THM (0); TRT Tracker: Testosterone Log (0); Stabilize: Rastreio de HRT (0) |
| exame de sangue | 23 | 1 | – | Testosterona Tracker: TRT AI (0) |
| peptídeo | 23 | 18 | – | PepDose: Calculadora Peptídeo (0); Halflife - Peptídeo GLP-1 Log (0); Tracker de Peptídeos: Peppy (0); GLP-1 Diário peptídeo: Glipath (0) |
| injeções | 24 | 20 | – | Meu GLP 1 / Diário de Injeções (0); GLP-1 Logbook: Injeções (0); Dosio - Injeções GLP-1 (0); Diário de Injeções - GLP-1 (0) |
| hormônio | 24 | 8 | – | Ciclo Hormonal - HorMonitor (0); LevePro (1); Hormoni Flow (1); Lunaglow: Ciclo e Hormônio (0) |
| trt | 22 | 8 | – | JTe (4648); TRT: Dose, Sintomas e Exames (0); TRT8 PAS (4); PinPoint TRT (0) |
| testosterona | 23 | 19 | – | TRT Tracker: Testosterone Log (0); Ciclo Hormonal - HorMonitor (0); Testosterona Tracker: TRT AI (0); TRT Calculator: Testosterone (0) |
| reposição hormonal | 5 | 2 | – | Ciclo Hormonal - HorMonitor (0); TRT: Dose, Sintomas e Exames (0) |
| reposição de testosterona | 3 | 3 | – | Testosterona Tracker: TRT AI (0); Ciclo Hormonal - HorMonitor (0); TRT: Dose, Sintomas e Exames (0) |
| trh | 23 | 3 | – | Menopausa e TRH: Sintomas (0); HRT AI: Menopausa e TRH (0); Menopausa: Perimenopausa e TRH (1) |
| hormônios | 25 | 9 | – | Solaia: Equilíbrio hormonal (14); Hormoni Flow (1); Hormony (0); Monora : Equilíbrio hormônio (0) |
| injeção | 24 | 16 | – | Dose: GLP-1 e Peptídeos (0); MEDS: Lembrete de Remédios (3); ShotTracker Log (1); Drop: Rastreador de injeção (0) |
| aplicação | 19 | 2 | – | GLP-1: Peso e Aplicação (0); Monju: Emagrecer com GLP-1 (12563) |
| exames de sangue | 25 | 0 | – | – |
| exames | 22 | 0 | – | – |
| peptídeos | 25 | 20 | – | PeptPro: Controle de Peptídeos (177); PepLab (4); Calculadora Peptídeos + (29); Rastreador de Peptídeos (0) |
| glp-1 | 25 | 23 | – | OzemPro: Emagrecer com GLP-1 (15893); Shotsy - Monitor GLP-1 (2278); Rastreador GLP-1 - GLPTracker (27); Dose: GLP-1 e Peptídeos (0) |
| trt tracker | 25 | 24 | 9 | TRT Tracker: Injections log (0); TRT Tracker: Testosterone Log (0); TRT: Dose, Sintomas e Exames (0); TRT Tracker: Log Testosterone (0) |
| ciclo | 20 | 0 | – | – |
| controle de injeções | 9 | 8 | – | Meu GLP 1 / Diário de Injeções (0); Solane: Controle de Injeções (0); Peptiva: controle GLP-1 (33); Shotlee: Controle GLP-1 e peso (1) |
| hormonio | 24 | 8 | – | Ciclo Hormonal - HorMonitor (0); LevePro (1); Hormoni Flow (1); Lunaglow: Ciclo e Hormônio (0) |
| deposteron | 1 | 1 | – | Peptide TRT Tracker / OptiPin (0) |
| ozempic | 25 | 24 | – | OzemPro: Emagrecer com GLP-1 (15893); Shotsy - Monitor GLP-1 (2278); GlipOne: Meu tratamento GLP-1 (1083); MounjaPRO: Emagrecer com GLP-1 (1050) |

### Storefront `se`

| Term | Results | Relevant in top 25 | Trough rank | Top relevant apps (ratings) |
|---|---|---|---|---|
| testosteron spruta | 3 | 3 | – | Peptide Tracker - PeptideKit (1); PeptideTrack: peptid tracker (0); Testosteron Tracker: TRT AI (0) |
| testosteronspruta | 0 | 0 | – | – |
| hormonterapi | 0 | 0 | – | – |
| blodvärden | 8 | 3 | – | PeptideTrack: peptid tracker (0); Testosteron Tracker: TRT AI (0); Vialora: TRT-injektionslogg (0) |
| peptider | 25 | 25 | – | Retamax: GLP-1 & Peptider (0); Peptide Tracker: Regimen (1); Stackr - Peptid Tracker (0); Peptide Vault: Peptide Tracker (0) |
| injektioner | 24 | 18 | – | GLP-1 Logbook: Injektioner (0); PinLog: Spåra injektioner (0); Shotsy - GLP-1 Spårare (697); GLP-1 Spårare Vikt & Injektion (0) |
| sprutor | 5 | 3 | – | Canetto: GLP-1 Peptide Tracker (0); Peptra: Peptiddoslogg (0); GLP Daily (0) |
| trt | 22 | 1 | – | Peptide & TRT Tracker: OptiPin (1) |
| testosteron | 24 | 23 | – | Testosterone Boost - TestPeak (0); TestoMax: Boost Testosterone (0); Testosterone Calculator Pro (0); Buff - Manhood Testosterone (0) |
| hormonbehandling | 5 | 4 | – | Klimakteriet – Dagbok & Symtom (0); TRT Tracker: Testosterone Log (0); HotFlash - Klimakteriet (0); Attune: HRT Tracker (0) |
| hormon | 18 | 12 | – | Hormona: Hormon & Menskalender (1029); Moody Month: Hormone Tracker (28); Health & Her App (8); Balance - Hormones & Menopause (46) |
| hormoner | 17 | 14 | – | Hormona: Hormon & Menskalender (1029); Moody Month: Hormone Tracker (28); Balance - Hormones & Menopause (46); Lively: Menstruation & Cykel (155) |
| injektion | 25 | 19 | – | Shotsy - GLP-1 Spårare (697); Medicin & Spruta Påminnelse (0); GLP-1 Spårare Vikt & Injektion (0); GLP-1: Vikt & Injektion (0) |
| spruta | 23 | 16 | – | Viktminskning Dagbok & Spruta (0); Medicin & Spruta Påminnelse (0); OneShot Bantningsspruta Dagbok (0); Spruta, spädning & areal (0) |
| blodprov | 24 | 5 | 17 | PeptideTrack: peptid tracker (0); IVF Dagbok – Fertilitetslogg (0); Hälsa Tracker & Health Tracker (0); Trough - TRT Tracker (0) |
| provsvar | 13 | 1 | – | Testosteron Tracker: TRT AI (0) |
| peptid | 25 | 25 | – | Peptidkalkylator PepFlow (1); PeptidePal – Peptide Tracker (10); Dosely - Peptide Tracker (0); Peptide Tracker & Calculator (2) |
| glp-1 | 25 | 23 | – | Shotsy - GLP-1 Spårare (697); GLP-1 Spårare - GLPTracker (8); DreamMe: GLP-1 Tracker Pet (2); Back2Me: GLP-1 tracker (0) |
| trt tracker | 24 | 23 | – | TRT Tracker: Log Testosterone (0); TRT Tracker: Dose & Bloodwork (0); Peptide & TRT Tracker: OptiPin (1); Anabolic Steroid & TRT Tracker (0) |
| medicin påminnelse | 22 | 1 | – | Medicin och Piller Påminnelser (0) |
| testosteronbehandling | 2 | 2 | – | Ekenhälsan (9); TRT Tracker: Testosterone Log (0) |