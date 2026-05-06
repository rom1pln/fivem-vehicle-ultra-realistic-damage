# fivem-vehicle-ultra-realistic-damage

## Description

`veh-ultra-realistic-damage` est une ressource FiveM conçue pour améliorer de façon significative le réalisme des dégâts véhicules sur un serveur RP.

Le système remplace le comportement vanilla de GTA V par une gestion avancée des collisions, des dommages moteur, des dégâts de carrosserie, des pneus, de la suspension, des vitres et des composants critiques du véhicule.

L’objectif est de proposer une conduite plus immersive et crédible, adaptée aux serveurs roleplay exigeants.

---

## Fonctionnalités

### Collisions réalistes

- Calcul des dégâts basé sur le Delta-V (variation de vitesse lors de l’impact)
- Prise en compte de l’angle du choc : avant / arrière / côté
- Différenciation entre impacts mineurs, modérés et sévères

### Dégâts mécaniques

- Dégradation progressive du moteur
- Perte de puissance moteur
- Fuites radiateur
- Fuites de carburant
- Risque de fumée moteur
- Possibilité d’incendie moteur si les dégâts deviennent critiques

### Dégâts physiques

- Pneus crevés selon la violence du choc
- Vitres cassées
- Portes pouvant se détacher
- Dégâts sur les phares
- Suspension endommagée après gros sauts ou mauvaises réceptions

### Influence de l’environnement

- Gestion différente selon le type de surface :
  - asphalte
  - gravier
  - roche
  - trottoir
  - terrain irrégulier

---

## Structure des fichiers

```text
veh-ultra-realistic-damage/
│
├── fxmanifest.lua
├── config.lua
└── client.lua
```

### `fxmanifest.lua`

Déclaration de la ressource FiveM.

### `config.lua`

Contient tous les paramètres personnalisables :

- intensité des dégâts
- seuils de collision
- probabilités de casse
- comportement moteur
- incendies
- suspension
- surfaces

### `client.lua`

Logique principale du système de dégâts côté client.

---

## Installation

### 1. Copier la ressource

Placez le dossier dans votre répertoire :

```text
resources/[vehicles]/veh-ultra-realistic-damage
```

### 2. Ajouter au `server.cfg`

```cfg
ensure veh-ultra-realistic-damage
```

### 3. Redémarrer le serveur

ou utilisez :

```cfg
refresh
ensure veh-ultra-realistic-damage
```

---

## Configuration recommandée

Exemples présents dans le script :

- impact mineur : `3.5 m/s`
- impact sévère : `12 m/s`
- feu moteur possible sous : `220 HP`
- jusqu’à `80%` de chance de crevaison sur gros choc latéral

Vous pouvez ajuster ces valeurs dans `config.lua` selon le niveau de réalisme souhaité.

---

## Compatibilité

Compatible avec :

- serveurs FiveM RP
- frameworks ESX
- frameworks QBCore
- serveurs standalone

Aucune dépendance obligatoire externe.

---

## Objectif RP

Cette ressource vise à éviter les véhicules « indestructibles » et à encourager :

- une conduite plus prudente
- des accidents crédibles
- des réparations RP cohérentes
- une meilleure immersion générale

---

## Auteur

Projet destiné à l’amélioration du réalisme véhicule sur FiveM.

README généré pour documentation et installation simplifiée.

