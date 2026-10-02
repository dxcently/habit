#!/usr/bin/env bash
# Runs every selection case and checks it against its expectation. A negative
# case must fail AND say something useful: the runner greps the real stderr, so
# a vague error is a failing test, not a passing one.
#
#   ./tests/selection/run.sh            # all cases
#   ./tests/selection/run.sh unknownProvider
set -uo pipefail
cd "$(dirname "$0")" || exit 1
root=$(cd ../.. && pwd)

# lib comes from the flake's own locked nixpkgs. A consumer applies habit to
# its own lib, so this tests the schema against one nixpkgs lib, not every
# consumer's. `checks.selection` sets HABIT_LIB to the same nixpkgs' lib,
# because a sandboxed build cannot fetch it. Given HABIT_LIB nothing is
# fetched, so the cases run against the dummy store: a real `nixosSystem` (the
# example cases) asks for a store while it evaluates but writes nothing to it,
# and a sandbox has no daemon to answer.
store=()
if [ -n "${HABIT_LIB:-}" ]; then
  lib="($HABIT_LIB)"
  store=(--store dummy://)
else
  rev=$(jq -r '.nodes.nixpkgs.locked.rev' "$root/flake.lock")
  lib="(builtins.getFlake \"github:nixos/nixpkgs/$rev\").lib"
fi

# case                              expect  substring the error must contain
cases=$(cat <<'EOF'
disabledIsInert                     ok      "fixture"
unselectedProviderIsInert           ok      "dunst"
unselectedAggregationIsInert        ok      "fixture"
missingProvider                     throws  chose no provider; available providers: dunst, herald, landmine, mako
unknownProvider                     throws  has no provider 'nope'; available providers: dunst, herald, landmine, mako
providerOnSingleImpl                throws  single implementation and takes no provider (got 'mako')
systemScopeWantsHomeOnlyProvider    throws  'notifications/mako' is selected for the system but exposes no nixos lane; it supports: homeManager
systemScopeWantsHomeOnlyDendrite    throws  'homeonly' is selected for the system but exposes no nixos lane; it supports: homeManager
homeScopeWantsSystemOnlyDendrite    throws  'systemonly' is selected by user 'alice' but exposes no homeManager lane; it supports: nixos
unknownDendrite                     throws  does not exist
unknownAggregation                  throws  does not exist
unknownAggregationSelector          throws  aggregation.workstation.compositor
aggregationProviderSelector         ok      "herald"
hostOverridesAggregationProvider    ok      "herald"
aggregationsMergeOnSharedDendrite   ok      true
conflictingAggregationProviders     throws  has conflicting definition values
hostDisablesAggregationMember       ok      false
aggregationRidesPlatformSettings    ok      "workstation-fixture"
backendAggregationIsInert           ok      "fixture"
backendAggregationIsReachable       throws  landmine/default.nix was imported
userAggregationContributesHomeMembers ok    true
userOverridesAggregationProvider    ok      "mako"
twoUserScopes                       ok      "mako+dunst"
scopesDoNotLeak                     ok      true
homeSelectionWithoutHomeManager     throws  homeManager.enable = false but selects home dendrites: notifications
homeManagerAbsent                   ok      true
aggregationMisspeltHalf             throws  has unknown field(s): member, sytem; a body takes only description, system, home
aggregationSystemKey                throws  has unknown field(s) in `system`: member; a half takes only members, providers, nixos, homeManager
aggregationHomeKey                  throws  has unknown field(s) in `home`: nixso; a half takes only members, providers, nixos, homeManager
aggregationListHalf                 throws  has `system` as a list, not an attrset; a half is an attrset taking only members, providers, nixos, homeManager
aggregationFunctionBody             throws  is a lambda, not an attrset; a body is an attrset taking only description, system, home
unselectedBadBodyIsInert            ok      true
overrideMatchesSelectedTarget       ok      "allhosts"
overrideHostFilterAdmits            ok      "allhosts,confined,homely"
overrideHostFilterExcludes          ok      "allhosts,homely"
overrideAppliesOnceForTwoTargets    ok      1
overrideNeedsSelectedTarget         ok      0
overrideNixosModuleApplies          ok      "allhosts"
overrideHomeOnlySelectionIsHostScoped ok    "patched"
overrideHomeModuleTargetsSelectingUserOnly ok "1:0"
overrideUnmatchedBodiesAreInert     ok      true
overrideMatchedBodyIsCallable       throws  tripwire overlay was evaluated
overrideUnknownField                throws  unknown field(s): nixOS; a record takes only
overrideNoTarget                    throws  names no dendrites; a record must say which capabilities
overrideStrayTarget                 throws  targets unknown dendrite(s): frobnicate
overrideStrayHost                   throws  confined to unknown host(s): gamma
overrideCarriesNothing              throws  carries nothing to apply
selectionModuleFieldIsVisible       ok      "sonata"
selectionModuleFieldIsUnknownWithoutIt throws does not exist
selectionModuleDrivesTheGatePass    ok      "workstation:notifications,systemonly"
extraModulesForLandsOnlyWhenSelected ok "1:0"
extraModulesForCanReachTheCatalogue throws  landmine/default.nix was imported
extraModulesForKeepsItsPosition     ok      "allhosts,hook"
hookDefaultsChangeNothing           ok      "same:true"
mkHostPassesTheModulesThrough       ok      "same:true"
extraModulesTakesTheWholeTree       throws  is the whole dendrite tree, which imports every dendrite's body
extraModulesForTakesTheWholeTree    throws  is the whole dendrite tree, which imports every dendrite's body
mergeRegistriesCatalogueUnion       ok      "homeonly,landmine,notifications,systemonly"
mergeRegistriesKeepsEveryValue      ok      "true"
mergeRegistriesIsOrderFree          ok      "true"
mergeRegistriesCatalogueClash       throws  catalogue names defined by more than one source: 'notifications' by alpha and gamma
mergeRegistriesSourceWithoutCatalogue ok "homeonly,notifications"
mergeRegistriesAggregationsUnion    ok      "desk,kiosk"
mergeRegistriesAggregationsClash    throws  aggregations names defined by more than one source: 'desk' by alpha and gamma
mergeRegistriesOverridesUnion       ok      "allhosts,confined"
mergeRegistriesOverridesClash       throws  overrides names defined by more than one source: 'allhosts' by alpha and gamma
mergeRegistriesFieldsAreIndependent ok      "homeonly,notifications:false"
mergedRegistrySelects               ok      "true"
mergeRegistriesThreeOwners          throws  'notifications' by alpha and gamma and delta
mergeSourceNotAnAttrset            throws  registry source at position 2 is a null, not an attrset
mergeSourceWithoutName              throws  registry source at position 2 has no string `name`
mergeSourcesShareAName              throws  registry sources share a name: alpha
mergeSourceUnknownField             throws  registry source 'typo' has unknown field(s): aggregation; a source takes only name, catalogue, aggregations, overrides
mergeFieldNotAnAttrset              throws  registry source 'nulled': `catalogue` must be an attrset, got null
overlayOrder                        ok      "lane,lane,record,caller,nucleus"
recordOverlayBeatsLane              ok      "record"
callerOverlayBeatsRecord            ok      "caller"
exampleMinimalInventory             ok      "box:ssh"
exampleMinimalModules               ok      ["path","set{services}","set{imports}"]
exampleMinimalConfig                ok      "box ssh=true"
exampleWorkstationInventory         ok      "bluetooth alice=notifications/dunst"
exampleWorkstationModules           ok      ["path","set{users}","set{hardware}","set{home-manager,imports}","set{imports}"]
exampleWorkstationConfig            ok      "desk bluetooth=true printing=false layout=de alice=true dunst=true mako=false"
exampleWorkstationSwitchedOffIsNeverImported ok 5
exampleWorkstationSwitchedBackOnIsImported throws landmine/default.nix was imported
exampleMergedInventory              ok      "dev:git,ssh,tmux"
exampleMergedModules                ok      ["path","set{programs}","set{services}","set{programs}","set{imports}"]
exampleMergedConfig                 ok      "git=true ssh=true tmux=true"
exampleMergedClash                  throws  catalogue names defined by more than one source: 'ssh' by shared and upstream
EOF
)

only="${1:-}"
pass=0; fail=0
printf '%-42s %s\n' "CASE" "RESULT"
printf '%s\n' "------------------------------------------------------------"
while read -r name expect want; do
  [ -z "$name" ] && continue
  [ -n "$only" ] && [ "$only" != "$name" ] && continue
  out=$(nix eval "${store[@]}" --impure --json --show-trace \
          --expr "(import ./cases.nix { lib = $lib; }).$name" 2>&1)
  rc=$?
  if [ "$expect" = ok ]; then
    if [ $rc -eq 0 ] && [ "$(printf '%s' "$out" | tail -1)" = "$want" ]; then
      printf '%-42s PASS\n' "$name"; pass=$((pass+1))
    else
      printf '%-42s FAIL (want %s, rc=%s)\n' "$name" "$want" "$rc"
      printf '%s\n' "$out" | tail -6 | sed 's/^/    | /'
      fail=$((fail+1))
    fi
  else
    if [ $rc -ne 0 ] && printf '%s' "$out" | grep -qF -- "$want"; then
      printf '%-42s PASS  (%s)\n' "$name" "$want"; pass=$((pass+1))
    else
      printf '%-42s FAIL (error missing %s, rc=%s)\n' "$name" "$want" "$rc"
      printf '%s\n' "$out" | grep -v '^ *$' | tail -8 | sed 's/^/    | /'
      fail=$((fail+1))
    fi
  fi
done <<< "$cases"

printf '%s\n' "------------------------------------------------------------"
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
