# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
# Install dependencies
cpanm --installdeps .

# Run all tests
prove -lvr t

# Run a single test
prove -lv t/02_module.t

# Run tests with verbose output
prove -lvr t 2>&1 | less
```

## Architecture Overview

Getopt::EX is a Perl module that extends Getopt::Long with user-definable option aliases, dynamic module loading, and RC file support.

### Core Module Relationships

```
Getopt::EX::Long (user-facing, Getopt::Long compatible)
    └── Getopt::EX::Loader (module/RC loading orchestration)
            └── Getopt::EX::Module (individual module/RC data container)
                    └── Getopt::EX::Func (function call interface)
```

### Key Components

**Getopt::EX::Long** (`lib/Getopt/EX/Long.pm`)
- Drop-in replacement for Getopt::Long
- Auto-loads `~/.${progname}rc` and `App::${progname}::default` module
- Handles `-M` module option parsing

**Getopt::EX::Loader** (`lib/Getopt/EX/Loader.pm`)
- Orchestrates loading of RC files and modules
- `deal_with(\@ARGV)` - main entry point that processes module options and expands user-defined options
- Manages BASECLASS for module namespace (e.g., `App::example`)

**Getopt::EX::Module** (`lib/Getopt/EX/Module.pm`)
- Container for parsed RC file or module data
- Handles RC file format: `option`, `define`, `expand`, `builtin`, `autoload`, `mode`, `help`
- Executes `__PERL__`/`__PERL5__` sections in RC files
- Calls module `initialize`/`finalize` hooks

**Getopt::EX::Func** (`lib/Getopt/EX/Func.pm`)
- Parses function call syntax: `funcname(arg1,arg2=val)` or `sub{...}`
- Converts arguments to key=>value pairs

**Getopt::EX::Colormap** (`lib/Getopt/EX/Colormap.pm`)
- ANSI terminal color handling (delegates to Term::ANSIColor::Concise)
- Supports labeled colors (`FILE=R`) and indexed color lists
- Can call arbitrary functions instead of producing color sequences

### Option Expansion Flow

1. Loader loads RC file and/or modules
2. `deal_with(\@ARGV)` processes `-M` options, loading additional modules
3. User-defined options are expanded recursively
4. Special tokens: `$<n>`, `$<shift>`, `$<move>`, `$<copy>`, `$<remove>`, `$<ignore>`
5. Built-in options are passed to Getopt::Long parser

### RC File Format

```
option --myopt --foo --bar=baz     # Define option alias
define MACRO  value                 # String macro (no shellwords)
expand --local --internal-only      # Module-local option
builtin --flag $variable            # Pass to Getopt::Long
autoload -Mmod --trigger            # Lazy module loading
mode function                       # Enable &func() expansion
mode wildcard                       # Enable glob expansion
```

### Module Lifecycle

Modules with `__DATA__` section are parsed as RC files. Hooks:
- `initialize($module_obj, $argv)` - called before function calls
- Function specified in `-Mmod::func(args)` - called next
- `finalize($module_obj, $argv)` - called last

## Perl Version

Requires Perl 5.14+. Uses `v5.14` features (say, state, unicode_strings).

## Coding Conventions

- Use `use parent` instead of `@ISA` for inheritance
- Use `croak` from Carp for user-facing errors
- Wrap symbol aliases in `no warnings 'once'` block
- Check `$@` (not `$!`) for eval errors; use pattern match like `$@ =~ /Can't locate/`
- Add comments for complex regex patterns (especially recursive ones)

## Testing

- Tests are in `t/` directory
- Test files should set `$ENV{HOME}` to `$t/home` for RC file tests
- Test RC files and modules are in `t/home/`
