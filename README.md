# Graphene

A simple dired for neovim.

Like the material graphene, the file viewer focusing on being simple, modest, and displays you filestructure as a single flat format, focusing on your immediate surroundings and allow you to create, rename, or mass-manipulate your file as you navigate the file structure layer by layer.

## Requirements

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

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
    ["<C-s>"] = actions.split,
    ["<C-v>"] = actions.vsplit,
    ["u"] = actions.up,
    ["h"] = actions.up,
    ["i"] = actions.open,
    ["r"] = actions.rename,
    ["D"] = actions.delete,
    [","] = actions.toggle_selected,
    ["y"] = actions.yank,
    ["d"] = actions.cut,
    ["p"] = actions.paste,
    ["O"] = actions.open_dir_external,
    ["o"] = actions.open_external,
    ["."] = actions.toggle_hidden,
  }
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
require"graphene".init([path])
```

## Features

### Hidden Files and Gitignore

By default, hidden files (starting with `.`) and git-ignored files are not
shown. Toggle visibility with `.` (or `actions.toggle_hidden`).

When opening graphene from a hidden file, hidden files are automatically shown
so the originating file is visible.

### File Metadata

In wider windows (80+ columns), graphene displays additional metadata:
- File size (human-readable with SI prefixes)
- Modification time
- Permission mode (unix-style rwx)

### Statusline Integration

For statusline plugins, `require"graphene".status()` returns a table with:
- `path`: The current directory path
- `dirname`: The directory name only
- `icon`: The directory icon

## Bulk File Operations

At any point, one or more files can be selected with `,`.

Use `d` to cut the files.

Navigate or create a folder and hit `p` to paste. The files will be moved to the
new location.

Use `y` to copy the marked files, and paste them with `p`.

If in visual mode, the currently selected lines will be used instead of the
marked items.

The clipboard is shared between all graphene instances, which means you can
copy, cut and paste between splits.

Renaming to an existing file will prompt for confirmation before overwriting.
