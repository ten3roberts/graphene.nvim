# Graphene

A simple simple asynchronous file explorer.

A developer should not be hindered by their file explorer.

Graphene allows you to easily browse your project, folder by folder, creating
files, moving them around, and perhaps most importantly: opening them.

Graphene is **not** a tree viewer. The mind only has so much capacity, and as
such, Graphene focuses on your immediate surroundings letting you be focused on
the files at hand.

## Setup
Simply call:

```lua
require "graphene".setup {}
```

## Configuration
```lua
local actions = require "graphene.actions"

require "graphene".setup {
  format_item = require "graphene.icons".format,
  highlight_items = require "graphene.icons".highlight,
  sort = default_sort,
  override_netrw = true,
  mappings = {
    ["<CR>"] = actions.edit,
    ["<Tab>"] = actions.edit,
    ["q"] = actions.quit,
    ["l"] = actions.edit,
    ["s"] = actions.split,
    ["v"] = actions.vsplit,
    ["u"] = actions.up,
    ["h"] = actions.up,
    ["i"] = actions.open,
    ["r"] = actions.rename,
    ["D"] = actions.delete,
  }
```

## Usage

```vim
:edit . " Open cwd
:edit /path/to/directory
```

or

```vim
Graphene " Open directory of current file
Graphene . " Open cwd
```

Graphene is also accessible through a lua api, if desired.

```lua
lua require"graphene".init([path])
```
