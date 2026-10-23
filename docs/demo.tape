# Re-record from the repository root:
#   vhs docs/demo.tape
#   gifsicle -O3 --colors 32 --lossy=20 docs/demo.gif -o docs/demo.gif.tmp
#   mv docs/demo.gif.tmp docs/demo.gif
#
# vhs writes a high-color GIF. The gifsicle step keeps it under 2 MB.
#
# docs/demo-shell.sh starts bash with HOME=/home/demo and a minimal PATH.
# Install Bun and gbrain for that placeholder account before recording:
#   HOME=/home/demo BUN_INSTALL=/home/demo/.bun bun install -g github:garrytan/gbrain#latest-stable
#
# The hidden preface copies this checkout to ~/kit and removes any previous
# ~/demo-vault and ~/.gbrain. The picture then runs setup, a search for the
# garden planner, a simulated agent session note, sync, and a second search.
# The on-screen prompt is demo@kit:~$.

Output docs/demo.gif

Require bash
Require tar
Require gbrain

Set Shell bash
Set FontFamily "JetBrains Mono"
Set FontSize 15
Set LineHeight 1.1
Set Width 860
Set Height 620
Set Padding 14
Set Framerate 5
Set TypingSpeed 32ms
Set Theme "Catppuccin Mocha"
Set WindowBar Rings
Set WindowBarSize 30
Set CursorBlink false
Set WaitTimeout 90s

Hide
Type@1ms "exec ./docs/demo-shell.sh"
Enter
Sleep 0.5s
Type@1ms "export PS1='demo@kit:~$ '"
Enter
Type@1ms "sh -c 'rm -rf $HOME/kit $HOME/demo-vault $HOME/.gbrain; mkdir -p $HOME/kit; tar --exclude .git -cf - . | tar -C $HOME/kit -xf -; echo demo-prep-ready'"
Enter
Wait+Screen@90s /demo-prep-ready/
Type@1ms "cd $HOME/kit"
Enter
Type@1ms "clear"
Enter
Sleep 0.4s
Show

Type "scripts/setup.sh ~/demo-vault"
Enter
Sleep 14s

Type "gbrain search 'offline bed map' --source obsidian-vault"
Enter
Sleep 3.2s

Type "bash docs/simulated-agent-step.sh ~/demo-vault"
Enter
Sleep 2.4s

Type "scripts/sync.sh ~/demo-vault"
Enter
Sleep 5s

Type "gbrain search 'cedar-latch' --source obsidian-vault"
Enter
Sleep 2.6s
Screenshot docs/demo-still.png
Sleep 1s
