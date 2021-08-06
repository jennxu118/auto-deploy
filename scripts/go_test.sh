name: Make a new release or hotfix branch
on:
  workflow_dispatch:
    inputs:
      release-version:
        description: Semantic version -M (majo) -m (minor) -p (patch) -h (hotfix patch)
        required: true
        default: '-p'

jobs:
  make-release:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ ubuntu-20.04 ]

    steps:
      - uses: actions/checkout@v2

      - name: Make a new release or hotfix branch
        if: success()
        shell: bash
        run: |
          chmod +x ./scripts/make-release.sh
          ./scripts/make-release.sh "${{ github.event.inputs.release-version }}"
        env:
          user.name: ${{ github.actor }}