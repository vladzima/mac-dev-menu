## Dev Servers for SwiftBar

In case you always forget which Node/bun/etc dev servers you have fired up on your machine and after a week discover localhost:xxxx is running something (like i do).

![](https://github.com/vladzima/mac-dev-menu/blob/main/preview.png?raw=true)

A SwiftBar plugin that shows your running local dev servers (React/Next/Vite, etc.) in the macOS menu bar: ports + project name, with quick actions.

#### What you’ll see

Menu bar:
* `D:N` — number of detected dev servers (processes listening on TCP ports).

Dropdown:
* One line per server: `5173 — transactions (vite)`
    * Click opens `http://localhost:<port>`
    * Submenu shows `cwd` + `Stop` (SIGTERM)

#### How names are detected

Project name:
1. `package.json:name` (if available next to `cwd`)
2. folder name after `/projects/<name>/...`
3. `basename(cwd)` fallback

Framework label (`next` / `vite` / `cra` / `webpack` / `parcel` / `astro` / `nuxt` / `remix`):
1. process command line (`ps`)
2. `package.json` (better if `python3` is available)


### Install
    git clone https://github.com/vladzima/mac-dev-menu.git
    cd mac-dev-menu
    ./install.sh

Optional: custom plugin folder
    ./install.sh "$HOME/SwiftBar"

### Use
Open SwiftBar, set "Plugin Folder" to the folder you used above.

#### Customize refresh rate

Rename the file:
* `dev-servers.5s.sh` (every 5s)
* `dev-servers.30s.sh` (every 30s)
