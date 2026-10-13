# CrossMix personnel : TrimUI Smart Pro TG5040

Paquet expérimental issu de main avec correctifs du packaging et de la migration.
Version non officielle. Smart Pro S et Brick exclus. build-info.txt identifie le commit.

## Préparation

1. Copier intégralement la carte SD sur un ordinateur, fichiers cachés inclus.
2. Faire des sauvegardes normales dans les jeux PSP en complément des savestates :
   les états peuvent être incompatibles entre versions de PPSSPP.
3. Sauvegarder les réglages du firmware (Wi-Fi, calibration) avec System Tools.
4. Mettre le firmware TG5040 à jour en 1.1.1 / 20251128 selon la procédure officielle
   TrimUI avant de tester ce paquet. Le firmware 1.0.4 est trop ancien.
   https://github.com/trimui/firmware_smartpro/releases/tag/v1.1.1
   Fichier : trimui_tg5040_20251128_v1.1.1.zip, pas l'image sd_recovery.
5. Vérifier ensuite /etc/version et /etc/openwrt_release.

## Archive

Télécharger les assets de release, pas les archives Source code.
Si le ZIP est découpé, télécharger toutes les parties .zip.partNN et les réunir
sur l'ordinateur. Exemple Linux/macOS pour la version 1.3.4 :

```sh
cat CrossMix-OS_v1.3.4.zip.part* > CrossMix-OS_v1.3.4.zip
shasum -a 256 -c SHA256SUMS
```

Les parties sont un découpage binaire pour respecter la limite des assets GitHub.
Ne pas ouvrir ou installer les parties séparément.

## Installation

Tester d'abord sur une seconde carte FAT32 : extraire le ZIP complet à la racine.
Apps, Emus, System, RetroArch et trimui doivent être directement à la racine.
Vérifier démarrage, son, commandes, Wi-Fi, jeux et PortMaster.

Pour migrer CrossMix existant, placer le ZIP complet fermé à la racine de la carte.
Un seul fichier CrossMix-OS_v*.zip doit être présent. Ne pas extraire par-dessus
l'installation existante : cela contournerait la migration.
La version numérique du paquet doit être supérieure à celle inscrite dans
System/usr/trimui/crossmix-version.txt. Le paquet par défaut est 1.3.4.
CrossMix propose l'installation au démarrage.

Le script demande 5000 Mo libres ; prévoir aussi la place du ZIP et une marge.
Le stockage interne doit disposer d'au moins 20 Mo libres.
Conserver _Updates/Backup_CrossMix_v* jusqu'à vérification des sauvegardes.

Les sauvegardes RetroArch passent au classement par cœur. En cas de fichiers
différents au même emplacement, le premier reste actif et les suivants sont
conservés dans Migration_Conflicts à l'intérieur de la sauvegarde _Updates.
Le journal signale les conflits ; choisir ensuite le fichier voulu manuellement.

Les réglages globaux des émulateurs ne sont pas tous conservés : CrossMix remplace
notamment la configuration globale PPSSPP. L'OTA reste celui du projet amont ;
ne pas utiliser l'OTA pour installer ce fork.

Si l'extraction échoue, le script s'arrête sans redémarrer. Restaurer la copie
intégrale de la carte avant de démarrer à nouveau.
