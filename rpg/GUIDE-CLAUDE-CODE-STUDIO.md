# Installer Claude Code et le connecter à Roblox Studio

But : que Claude travaille **sur ton ordinateur**, directement dans Roblox
Studio. Il pourra voir le vrai rendu (captures d'écran), tester en jouant et
générer les créatures (ogre, hippogriffe, araignée) avec l'IA de Studio.

Durée : environ 15 minutes. Les commandes viennent des documentations
officielles (liens en bas de page).

> ⚠️ D'après Roblox : *« MCP clients can read and modify content in your open
> Roblox places. Make sure to only connect clients you trust. »* Claude pourra
> modifier la place ouverte dans Studio : sauvegarde-la avant les grosses
> opérations.

## Ce qu'il te faut

- **Roblox Studio à jour** (Roblox demande la dernière version).
- Un abonnement Claude qui inclut Claude Code (Pro, Max, Team, Enterprise…).
  Le plan gratuit de claude.ai ne l'inclut pas. Tu l'utilises déjà ici, donc
  c'est bon.
- **Git**, pour récupérer le projet :
  - Windows : installe [Git for Windows](https://git-scm.com/downloads/win).
    Claude Code s'en sert aussi pour son outil Bash.
  - macOS : tape `git --version` dans le Terminal ; s'il manque, macOS propose
    en général de l'installer.

## Étape 1 — Installer Claude Code

**Windows** : ouvre **PowerShell** (pas l'Invite de commandes), sans droits
administrateur, puis :

```powershell
irm https://claude.ai/install.ps1 | iex
```

**macOS** : ouvre le **Terminal**, puis :

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

L'installation n'affiche pas de progression pendant le téléchargement. Ensuite,
**ouvre une nouvelle fenêtre** de PowerShell ou de Terminal et vérifie :

```bash
claude --version
```

Un numéro de version doit s'afficher.

Si ça coince sous Windows :
- `'irm' n'est pas reconnu…` : tu es dans l'Invite de commandes ; ouvre
  PowerShell.
- `claude` ouvre l'application Claude Desktop au lieu de Claude Code : mets
  Claude Desktop à jour.

## Étape 2 — Récupérer le projet

Dans PowerShell ou le Terminal, place-toi où tu veux garder le projet, puis :

```bash
git clone https://github.com/Zaylomgl/roblox.git
```

```bash
cd roblox
```

Le dépôt peut demander une connexion à GitHub : suis la fenêtre qui s'ouvre.

## Étape 3 — Lancer Claude Code et te connecter

Toujours dans le dossier `roblox` :

```bash
claude
```

La première fois, Claude Code te demande de te connecter : suis les étapes dans
le navigateur. Laisse cette fenêtre ouverte.

## Étape 4 — Activer le MCP dans Roblox Studio

1. **Redémarre Roblox Studio**, pour qu'il détecte Claude Code qui vient
   d'être installé, puis ouvre la place du jeu.
2. Ouvre **Assistant**.
3. Clique sur **…** > **Manage MCP Servers**.
4. Active **Enable Studio as MCP server**.
5. Dans **Quick connect**, active **Claude Code**.

Quand la connexion fonctionne, Studio affiche un **indicateur vert** avec le
nombre de clients connectés. Si Claude Code n'apparaît pas dans la liste,
redémarre Studio.

### Si « Quick connect » ne marche pas (méthode manuelle)

Ferme Claude Code (tape `/exit`), puis dans PowerShell ou le Terminal :

**Windows** :

```powershell
claude mcp add --scope user Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
```

**macOS** :

```bash
claude mcp add --scope user Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
```

Vérifie (Studio doit être ouvert) :

```bash
claude mcp list
```

La ligne `Roblox_Studio` doit afficher `✔ Connected`. Relance ensuite `claude`.
Ces commandes combinent le chemin donné par Roblox et la syntaxe
`claude mcp add` de la documentation de Claude Code.

## Étape 5 — Premier test

Dans Claude Code, copie ce message :

```text
Lis CLAUDE.md et rpg/CONCEPTION.md. Ensuite, avec le MCP de Roblox Studio :
liste les Studio ouverts, fais une capture d'écran de la place ouverte et
montre-la-moi. Ne modifie rien pour l'instant.
```

Si Claude te montre la capture, tout fonctionne. Préviens-moi et on passe aux
créatures.

## (Facultatif) Publier depuis ton ordinateur

Pour que Claude puisse aussi publier et lancer les tests du vrai moteur depuis
ton ordinateur, il lui faut la clé API dans la variable d'environnement
`ROBLOX_API_KEY`. Ne l'écris jamais dans un fichier du projet. Ce n'est pas
nécessaire pour commencer : la publication peut rester dans la session cloud.

## Sources

- Installation de Claude Code : <https://code.claude.com/docs/en/setup>,
  <https://code.claude.com/docs/en/troubleshoot-install>
- Serveurs MCP dans Claude Code : <https://code.claude.com/docs/en/mcp>
- MCP de Roblox Studio : <https://create.roblox.com/docs/studio/mcp>
