# Étude et port de Moonlight Next UI pour CrossMix

## Cible et architecture

Branche : `codex/moonlight-next-ui`, issue de `main` au commit `9e543fd0`.
Cible initiale : Smart Pro originale, CrossMix 1.3.11/1.3.12 et firmware 1.1.1. Cette combinaison est la base de travail, pas une certification de compatibilité. Brick et Smart Pro S ne sont pas ciblées par le lanceur.

Le [projet retenu](https://github.com/richieszemeredi/nextui-moonlight-pak/tree/v0.1.0) est une interface C/SDL2 pour gérer plusieurs PC, afficher le PIN, choisir une application Sunshine et régler résolution/FPS/débit. Il appelle le client `moonlight` existant. À distinguer de l'[ancien wrapper de josegonzalez](https://github.com/josegonzalez/trimui-brick-moonlight-pak), qui ouvre simplement `moonlightui`, l'interface d'origine du firmware.

CrossMix possède déjà des icônes Moonlight et un ajustement du lanceur du firmware dans `System/starts/°customization.sh`. Ce nouveau port est une App SD indépendante ; aucune modification de cette intégration ni aucun flash du firmware n'est nécessaire pour installer l'App.

## Sources reproductibles

- UI : tag `v0.1.0`, licence MIT, sources `src/` conservées avec adaptations CrossMix.
- Apostrophe : commit `c6b57bd8bbfc0da27813d818cc22f7bec38bf600` de [Helaas/Apostrophe](https://github.com/Helaas/Apostrophe/tree/c6b57bd8bbfc0da27813d818cc22f7bec38bf600), deux en-têtes et licence MIT dans `third_party/apostrophe/`.
- Archive publiée étudiée : `Moonlight.pakz`, SHA256 `8301c56cc00d422f21e2da9835c9d22c13a5b68449c8878ff026e3b81f7fb4ae`. Aucun de ses binaires n'est distribué ici.
- Compilation : image amont `ghcr.io/loveretro/tg5040-toolchain` figée au digest `sha256:f131c6af64029a8723d0ce8d3c2682642f5f091b04714f6beedda9bec18477ab`, compilateur `aarch64-nextui-linux-gnu-gcc`, Cortex-A53. `MOONLIGHT_TOOLCHAIN_IMAGE` permet de tester une autre image explicitement.

Les dépendances de liaison sont SDL2, SDL2_ttf, SDL2_image, pthread, libm et la libc du SDK. Sur console, elles doivent correspondre aux bibliothèques du firmware (`/usr/trimui/lib`) et de CrossMix (`System/lib`). La compilation avec le SDK NextUI ne garantit pas à elle seule leur compatibilité ABI : vérifier le chargeur ELF, les versions GLIBC, les symboles SDL et les dépendances avec `readelf` puis un lancement réel. Ne pas remplacer globalement la libc ou SDL du système pour contourner un défaut de liaison.

## Adaptations réalisées

| Besoin | Mise en œuvre |
| --- | --- |
| Entrée dans MainUI | `Apps/MoonlightNextUI/config.json`, icône Moonlight CrossMix, lanceur indépendant du répertoire courant. |
| CLI du firmware | Recherche dans le PATH incluant `/usr/trimui/apps/moonlight` et `/usr/trimui/bin`, message explicite si absent. Vérifier son emplacement et ses options sur la console. |
| Ressources UI | Police CrossMix via `MOONLIGHT_FONT`, thème Apostrophe par défaut. Pas d'installation de NextUI, `nextval.elf`, `.system` ou sprites provenant de NextUI. |
| Bouton Power et CPU | `is_nextui=false` et `AP_CPU_SPEED_DEFAULT` aux deux initialisations. Aucun handler Power NextUI. L'adaptateur `Apps/MoonlightNextUI/moonlight` applique uniquement pendant le stream le réglage déjà utilisé par CrossMix pour son Moonlight d'origine : governor performance, maximum 1608000 kHz. Il restaure les valeurs précédentes à la sortie du client. Pair/list ne changent rien au CPU. |
| Persistance | `Data/MoonlightNextUI`, HOME et XDG dédiés ; aucune suppression des clés historiques. |
| Smart Pro | Défaut 1280×720 / 60 FPS / 10 Mbps au lieu de 1024×768 / 20 Mbps. |
| Exécution du client | `execvp` avec arguments séparés pour pair/list/stream : noms d'applications et adresses ne passent plus par un shell. |
| Retour après streaming | Vérification de la réinitialisation SDL, erreur journalisée si elle échoue. |
| Livraison | Script Docker et workflow GitHub Actions produisant un ZIP SD autonome. Aucun téléchargement ni mise à jour automatique sur console. |

Le marqueur NextUI `/tmp/stay_awake` n'est pas créé : son interprétation par le firmware CrossMix n'est pas démontrée. L'absence de mise en veille automatique pendant un stream doit donc être testée ; adapter ensuite uniquement le mécanisme réellement utilisé par le firmware. Le port conserve les widgets et fonctionnalités amont ; l'interface reste en anglais et n'importe pas automatiquement le thème CrossMix.

## Vérifications restantes avant livraison utilisable

1. Compilation réalisée sur GitHub Actions le 15 octobre 2026, run [38753079087](https://github.com/otassetti/CrossMix-OS/actions/runs/38753079087) : tests du lanceur et du vrai wrapper CLI réussis, ZIP vérifié, ELF64 AArch64 de 141168 octets, références GLIBC_2.17. Dépendances directes relevées : SDL2, SDL2_image, SDL2_ttf, libc, libm et libpthread. La résolution de ces bibliothèques reste à confirmer sur console.
2. Installer uniquement le ZIP App sur une Smart Pro avec firmware 1.1.1. Vérifier lancement à froid, lisibilité de la police, croix/boutons/clavier et fermeture vers Apps.
3. Ajouter deux PC, sélectionner le serveur actif, redémarrer l'App et vérifier la persistance sur SD.
4. Appairer Sunshine avec le PIN, annuler un appairage, tester serveur absent, liste vide et PC non appairé. Vérifier que le Moonlight d'origine reste utilisable.
5. Streamer à 720p en 30 puis 60 FPS ; vérifier décodage matériel, son, manettes et sortie Select + Start. Revenir à l'UI et relancer plusieurs fois.
6. Vérifier Power court/long, veille/réveil et streaming prolongé. Relever température, charge CPU, coupure Wi-Fi et éventuelle veille automatique indésirable.
7. Comparer la qualité/latence au Moonlight d'origine avec le même PC et les mêmes réglages. Conserver logs et versions exactes.

Le code amont conserve notamment ses threads d'appairage et de liste. Les cas d'annulation et de timeout doivent être observés sur matériel avant de qualifier la fonction de stable. Le binaire CrossMix a été compilé par GitHub Actions ; il est disponible dans l'artefact ZIP du workflow. Le dépôt conserve les sources, et le dossier local `build/` contient le paquet récupéré. L'application reste expérimentale jusqu'aux essais sur console.

### Premier retour console et correctif de performances

Le propriétaire confirme que l'App fonctionne, mais signale des saccades et une forte latence des entrées en 1024×768 / 10 Mb/s via Wi-Fi. La comparaison avec Moonlight d'origine et le FPS utilisé ne sont pas encore connus. L'analyse du dépôt montre que l'appel direct au client contournait l'optimisation CPU du lanceur d'origine ajoutée par `System/starts/°customization.sh`. Le nouvel adaptateur reprend cette politique et restaure le CPU à la fin du stream. Les tests isolés couvrent l'application de la politique et la restauration après un échec du client. Cela corrige un écart d'intégration ; la cause réelle du lag et l'amélioration sur console restent à confirmer.
