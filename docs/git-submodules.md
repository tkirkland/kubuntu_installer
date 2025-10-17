# Git Submodules Reference Guide

This document explains how to work with Git submodules in the kubuntu_installer project.

## Overview

This project uses Git submodules to manage external library dependencies:

- **`libs/input.sh`** - Controlled input library from https://github.com/tkirkland/input.sh
- **`libs/string_output.sh`** - Output formatting library from https://github.com/tkirkland/string_output.sh

Submodules allow us to:
- Track specific versions of external dependencies
- Keep libraries separately maintained in their own repositories
- Prevent accidental modifications to upstream code
- Ensure reproducible builds across all environments

## For Users: Cloning the Project

### Method 1: Clone with Submodules (Recommended)

```bash
# Clone the repository with all submodules in one command
git clone --recursive https://github.com/tkirkland/kubuntu_installer.git
cd kubuntu_installer

# Verify submodules are initialized
git submodule status
```

**Output should show:**
```
 b548473d0ca221964794a69000941fa44765b39f libs/input.sh (heads/master)
 b04a2e480f2029769868b8a1abc1b6d4b977fa41 libs/string_output.sh (v1.1.0-4-gb04a2e4)
```

### Method 2: Initialize After Cloning

If you already cloned without `--recursive`:

```bash
# Standard clone (submodule directories will be empty)
git clone https://github.com/tkirkland/kubuntu_installer.git
cd kubuntu_installer

# Initialize and fetch submodules
git submodule init
git submodule update

# Or combine into one command
git submodule update --init --recursive
```

## For Developers: Working with Submodules

### Checking Submodule Status

```bash
# View submodule status (commit hashes and branches)
git submodule status

# View detailed submodule information
git submodule foreach 'echo $name at $(git rev-parse HEAD)'

# Show submodule configuration
cat .gitmodules
```

### Updating Submodules to Latest Versions

```bash
# Update a specific submodule to its latest commit
cd libs/string_output.sh
git pull origin master
cd ../..

# Update the parent repository to track the new commit
git add libs/string_output.sh
git commit -m "chore: update string_output.sh to latest version"

# --- OR ---

# Update all submodules to their latest commits
git submodule update --remote --merge

# Commit the updated submodule pointers
git add .gitmodules libs/
git commit -m "chore: update all submodules to latest versions"
```

### Viewing Submodule Changes

```bash
# Show which commit each submodule is at
git submodule status

# View changes in submodules since last commit
git diff --submodule

# View detailed diff including submodule file changes
git diff --submodule=diff
```

### Making Changes to Submodule Code

**⚠️ NEVER EDIT SUBMODULE FILES DIRECTLY IN THIS PROJECT**

Submodules are maintained in separate repositories. To modify them:

1. **Clone the submodule's repository separately:**
   ```bash
   cd ~/projects
   git clone https://github.com/tkirkland/string_output.sh.git
   cd string_output.sh
   ```

2. **Make your changes and commit:**
   ```bash
   # Edit files
   vim string_output.sh

   # Commit changes
   git add string_output.sh
   git commit -m "feat: add new formatting function"
   git push origin master
   ```

3. **Update the submodule in kubuntu_installer:**
   ```bash
   cd ~/projects/kubuntu_installer
   git submodule update --remote libs/string_output.sh
   git add libs/string_output.sh
   git commit -m "chore: update string_output.sh with new formatting function"
   git push
   ```

## Common Operations

### Checking Out a Specific Submodule Version

```bash
# Enter the submodule directory
cd libs/string_output.sh

# Check out a specific version tag
git checkout v1.2.0

# Return to parent directory
cd ../..

# Commit the submodule pointer change
git add libs/string_output.sh
git commit -m "chore: pin string_output.sh to v1.2.0"
```

### Removing a Submodule

If you need to remove a submodule:

```bash
# Remove submodule entry from .gitmodules
git config -f .gitmodules --remove-section submodule.libs/string_output.sh

# Remove submodule entry from .git/config
git config -f .git/config --remove-section submodule.libs/string_output.sh

# Remove the submodule directory from Git index
git rm --cached libs/string_output.sh

# Remove the submodule directory
rm -rf libs/string_output.sh

# Commit the changes
git add .gitmodules
git commit -m "chore: remove string_output.sh submodule"
```

### Adding a New Submodule

```bash
# Add new submodule
git submodule add https://github.com/username/new-library.git libs/new-library

# Initialize and update
git submodule update --init --recursive

# Commit the changes
git add .gitmodules libs/new-library
git commit -m "feat: add new-library submodule"
```

## Troubleshooting

### Submodule Directories Are Empty

```bash
# Initialize and update all submodules
git submodule update --init --recursive
```

### Submodule Is on Detached HEAD

This is normal. Submodules track specific commits, not branches.

```bash
# To update to latest commit on tracked branch
git submodule update --remote --merge

# Or enter submodule and checkout a branch
cd libs/string_output.sh
git checkout master
git pull
cd ../..
git add libs/string_output.sh
git commit -m "chore: update submodule to latest master"
```

### Submodule Has Uncommitted Changes

```bash
# View what changed
cd libs/string_output.sh
git status
git diff

# Discard changes (be careful!)
git reset --hard HEAD

# Or commit changes to upstream (if you're a maintainer)
git add .
git commit -m "fix: corrections"
git push origin master
```

### Conflicts When Updating Submodules

```bash
# Reset submodule to clean state
git submodule update --force --recursive

# Or resolve conflicts manually
cd libs/string_output.sh
git merge --abort  # if in middle of merge
git reset --hard origin/master
cd ../..
```

### Error: "fatal: transport 'file' not allowed"

This occurs when trying to add a local path as a submodule. Use HTTPS or SSH URLs:

```bash
# Wrong
git submodule add /path/to/local/repo libs/module

# Correct
git submodule add https://github.com/user/repo.git libs/module
```

## Best Practices

### For All Team Members

1. **Always clone with `--recursive`** to get submodules automatically
2. **Never modify files inside submodule directories** - make changes upstream
3. **Run `git submodule update`** after pulling to sync submodule versions
4. **Check submodule status** before commits to avoid accidental changes

### For Maintainers

1. **Pin to stable versions** - Use tags or specific commits, not floating branches
2. **Test after submodule updates** - Verify compatibility before committing
3. **Document version requirements** - Note which versions are tested/supported
4. **Update regularly but deliberately** - Don't blindly pull latest versions

### For CI/CD Pipelines

```bash
# Ensure submodules are fetched in CI
git clone --recursive https://github.com/tkirkland/kubuntu_installer.git

# Or if already cloned
git submodule update --init --recursive
```

## Understanding Submodule Structure

### The `.gitmodules` File

```ini
[submodule "libs/input.sh"]
    path = libs/input.sh
    url = https://github.com/tkirkland/input.sh
[submodule "libs/string_output.sh"]
    path = libs/string_output.sh
    url = https://github.com/tkirkland/string_output.sh
```

This file tracks:
- **path**: Where the submodule is located in the project
- **url**: Where to fetch the submodule from

### Submodule Commits in Parent Repository

When you run `git status` after changing a submodule, you'll see:

```
modified:   libs/string_output.sh (new commits)
```

This means the parent repository is tracking a *pointer* to a specific commit in the submodule.
You must commit this pointer change to update which version the project uses.

### The `.git/modules/` Directory

Git stores actual submodule repositories in `.git/modules/libs/`. The `libs/` directories
are working copies that reference these internal repositories.

## Quick Reference

| Task | Command |
|------|---------|
| Clone with submodules | `git clone --recursive <url>` |
| Initialize after clone | `git submodule update --init --recursive` |
| Update to latest version | `git submodule update --remote` |
| Check submodule status | `git submodule status` |
| View submodule commits | `git diff --submodule` |
| Add new submodule | `git submodule add <url> <path>` |
| Remove submodule | See "Removing a Submodule" section |

## Additional Resources

- [Official Git Submodules Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [GitHub Submodules Guide](https://github.blog/2016-02-01-working-with-submodules/)
- [Atlassian Submodules Tutorial](https://www.atlassian.com/git/tutorials/git-submodule)

## Project-Specific Notes

### Current Submodules

| Submodule | Repository | Purpose |
|-----------|------------|---------|
| `libs/input.sh` | https://github.com/tkirkland/input.sh | Controlled user input with validation |
| `libs/string_output.sh` | https://github.com/tkirkland/string_output.sh | Formatted output with colors and wrapping |

### Version Policy

- Submodules should track **stable releases** when available
- Use version tags (e.g., `v1.2.0`) for production releases
- Test compatibility after any submodule updates
- Document breaking changes in commit messages

### Contribution Workflow

If you need to modify a library:

1. Fork the submodule's repository on GitHub
2. Make changes in your fork
3. Submit a pull request to the upstream repository
4. After merge, update the submodule pointer in kubuntu_installer
5. Test thoroughly before committing the update

---

**Last Updated**: 2025-10-17
**Project**: kubuntu_installer
**Maintainer**: See repository for current maintainer information
