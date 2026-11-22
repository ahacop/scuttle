build:
    swift build --jobs 4

test:
    swift test --jobs 4
    python3 -m unittest discover -s scripts/tests -v

bundle *flags:
    scripts/bundle.sh {{flags}}

# Debug bundle, replace any running scuttle, and run attached so logs stream here (fut's run extension uses this).
run: kill
    scripts/bundle.sh --debug
    ./build/scuttle.app/Contents/MacOS/scuttle

kill:
    pkill -f "scuttle.app/Contents/MacOS/scuttle" || true

vm-install: bundle
    scripts/vm-install.sh

# Symlink the bundled CLI into ~/.local/bin so `scuttle <command>` works from any shell.
install: bundle
    mkdir -p ~/.local/bin
    ln -sf "$PWD/build/scuttle.app/Contents/MacOS/scuttle" ~/.local/bin/scuttle
    ls -l ~/.local/bin/scuttle

# Serve the manual at http://localhost:4000, on every interface, and rebuild it as docs/ changes.
docs:
    cd docs && jekyll serve --livereload --host 0.0.0.0

# Fuzz the debug build in the Tart VM: random actions, layout invariants checked after each. See scripts/fuzz.py.
fuzz seed="1" steps="150": build
    scripts/vm-fuzz.sh {{seed}} {{steps}}
