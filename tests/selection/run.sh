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
selectedModuleIsImported            throws  landmine/default.nix was imported
unselectedProviderIsInert           ok      "dunst"
unselectedAggregationIsInert        ok      "fixture"
missingProvider                     throws  chose no provider; available providers: dunst, herald, landmine, mako
unknownProvider                     throws  has no provider 'nope'; available providers: dunst, herald, landmine, mako
providerOnSingleImpl                throws  single implementation and takes no provider (got 'mako')
homeOnlyModuleSelectedForTheSystemAppliesAnEmptySystemHalf ok "sys= alice=homeonly"
homeOnlyProviderSelectedForTheSystemAppliesAnEmptySystemHalf ok "sys= alice=mako"
systemOnlyModuleSelectedByAUserAppliesItsSystemHalf ok "sys=systemonly alice="
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
hostSelectionReachesEveryHomeUser   ok      "sys=dunst alice=dunst bob=dunst"
userSelectionReachesThatUserOnly    ok      "sys=dunst alice=dunst bob="
hostAndUserSelectionApplyOnce       ok      "sys=dunst alice=dunst bob=dunst"
usersSelectingOneModuleApplyItsSystemHalfOnce ok "sys=dunst alice=dunst bob=dunst"
hostAndUserWithDifferentProvidersAreRefused throws dendrite 'notifications' is selected with different providers (host: dunst; user 'alice': herald); one system takes one implementation
usersWithDifferentProvidersAreRefused throws dendrite 'notifications' is selected with different providers (user 'alice': mako; user 'bob': dunst); one system takes one implementation
hostSelectionSkipsAUserWithoutHomeManager ok "sys=dunst alice=dunst"
hostSelectionWithoutHomeUsersEmitsNoHomeHalf ok "dunst"
userModuleRoutesItsHalves           ok      "accounts=alice,bob alice=true homes=alice"
homeSelectionWithoutHomeManager     throws  has home.enable = false but selects home dendrites: notifications
homeManagerAbsent                   ok      "systemonly accounts=bob"
selectedFollowsEachScope            ok      "sys=notifications/dunst,systemonly alice=homeonly bob="
selectedHoldsEveryCatalogueName     ok      "homeonly,landmine,notifications,systemonly landmine=false"
selectedIsReadOnlyInTheSystemEval   throws  The option `habit.selected' is read-only, but it's set multiple times
selectedIsReadOnlyInAUsersHome      throws  The option `home-manager.users.alice.habit.selected' is read-only, but it's set multiple times
laneRecordIsRefusedWhereTheSystemHalfIsEvaluated throws does not exist
selectedModuleDeclaresItsOptions    ok      "true"
hostWithoutHomeUsersNeverForcesAHomeHalf ok "homeThrows"
homeHalfIsReadWhenAUserReceivesIt   throws  habit.home was read
selectedAndImportedTwiceIsRefused   throws  is already declared in
aggregationMisspeltHalf             throws  has unknown field(s): member, sytem; a body takes only description, system, home
aggregationSystemKey                throws  has unknown field(s) in `system`: member; a half takes only members, providers, module
aggregationHomeKey                  throws  has unknown field(s) in `home`: nixso; a half takes only members, providers, module
aggregationListHalf                 throws  has `system` as a list, not an attrset; a half is an attrset taking only members, providers, module
aggregationFunctionBody             throws  is a lambda, not an attrset; a body is an attrset taking only description, system, home
unselectedBadBodyIsInert            ok      true
overrideMatchesSelectedTarget       ok      "allhosts"
overrideHostFilterAdmits            ok      "allhosts,confined,homely"
overrideHostFilterExcludes          ok      "allhosts,homely"
overrideAppliesOnceForTwoTargets    ok      1
overrideNeedsSelectedTarget         ok      0
overrideSystemModuleApplies         ok      "allhosts"
overrideHomeOnlySelectionIsHostScoped ok    "patched"
overrideHomeModuleReachesOnlyTheSelectingUser ok "1:0"
overrideHomeModuleReachesEveryUserForAHostSelectedTarget ok "1:1"
overrideHomeModuleLandsInTheSelectingUsersHome ok "bob=dunst+homely alice="
homeModulesKeepTheirPosition        ok      "aggregation,homely,dunst"
overrideUnmatchedBodiesAreInert     ok      true
overrideMatchedBodyIsCallable       throws  tripwire overlay was evaluated
overrideUnknownField                throws  unknown field(s): nixOS; a record takes only
overrideNoTarget                    throws  names no dendrites; a record must say which capabilities
overrideStrayTarget                 throws  targets unknown dendrite(s): frobnicate
overrideStrayHost                   throws  confined to unknown host(s): gamma
overrideCarriesNothing              throws  carries nothing to apply
selectionModuleFieldIsVisible       ok      "sonata"
selectionModuleFieldIsUnknownWithoutIt throws does not exist
selectionModuleFieldIsDeclaredInThePlatformEvaluation ok "sonata"
selectionModuleReservedNameDendrites throws hooks/reservedDendrites.nix declares habit.dendrites; habit reserves dendrites, aggregation, users, selected, home
selectionModuleReservedNameHome     throws  hooks/reservedHome.nix declares habit.home; habit reserves dendrites, aggregation, users, selected, home
selectionModuleDrivesTheGatePass    ok      "workstation:notifications,systemonly"
extraModulesForLandsOnlyWhenSelected ok "1:0"
extraModulesForCanReachTheCatalogue throws  landmine/default.nix was imported
extraModulesForKeepsItsPosition     ok      "allhosts,hook,systemonly"
scanReadsHabitKeysAndNothingElse    ok      "host=notifications/herald,systemonly groups=workstation alice=homeonly"
topLevelSelectionKeysAreRefusedByThePlatformEvaluation throws The option `dendrites' does not exist
scanDoesNotFollowImports            ok      "host=systemonly groups= alice="
platformEvaluationFollowsImports    throws  hosts/importThrows.nix was imported
scanDropsImportsGuardedByConfig     ok      "host=systemonly groups= alice="
scanReadsAHostWithAnArgsHead        ok      "host=systemonly groups= alice="
scanLeavesAGuardWithoutHabitKeysUnforced ok "host=systemonly groups= alice="
scanTypoIsAnOptionThatDoesNotExist  throws  The option `habit.dendrtes' does not exist
scanTypoSuggestsTheKeyItMeant       throws  Did you mean `habit.dendrites'
scanPoisonsAHabitKeyUnderMkIf       throws  hosts/mkIfHabitKey.nix reads `config` while selection is being read; selection may not depend on platform configuration
scanPoisonsAMkIfAroundConfig        throws  hosts/mkIfConfigKey.nix reads `config` while selection is being read; selection may not depend on platform configuration
scanPoisonsAMkIfAroundTheHost       throws  hosts/mkIfTopLevel.nix reads `config` while selection is being read; selection may not depend on platform configuration
scanPoisonsHabitItselfUnderMkIf     throws  hosts/mkIfHabit.nix reads `config` while selection is being read; selection may not depend on platform configuration
scanPoisonsPkgs                     throws  hosts/usesPkgs.nix reads `pkgs` while selection is being read; selection may not depend on platform configuration
scanPoisonsOptions                  throws  hosts/usesOptions.nix reads `options` while selection is being read; selection may not depend on platform configuration
scanPoisonsOsConfig                 throws  hosts/usesOsConfig.nix reads `osConfig` while selection is being read; selection may not depend on platform configuration
scanDropsRequire                    ok      "host=systemonly groups= alice="
scanNamesAMissingHostArgument       throws  hosts/usesMissingArg.nix takes argument(s) username which the scan does not provide; pass them in specialArgs
scanDropsImportsThatNeedAnArgumentItLacks ok "host=systemonly groups= alice="
scanTakesTheCallersSpecialArgs      ok      "carol"
scanTakesTheCallersLib              ok      "caller"
platformHoldsWhatTheScanRead        ok      "none"
selectionInAnImportedFileFailsAnAssertion throws hosts/selectsInImport.nix but the host scan never saw it (scans do not follow `imports`)
selectionInAnImportedFileIsNamed    throws  `habit.dendrites.systemonly.enable` is set in
providerInAnImportedFileFailsAnAssertion throws `habit.aggregation.workstation.notifications.provider` is set in
userInAnImportedFileFailsAnAssertion throws `habit.users.carol.definition` is set in
hookKeyInAnImportedFileFailsAnAssertion throws `habit.tag` is set in
homeConfigInAnImportedFileFailsAnAssertion throws `habit.users.alice.home.config.fixture.marks` is set in
aKeyAnImportedFileRepeatsIsStillRefused throws hosts/selectsInImport.nix but the host scan never saw it (scans do not follow `imports`)
inlineImportIsCaughtByItsValue      throws  hosts/importsInline.nix but the host scan never saw it (scans do not follow `imports`)
hostWithItsOwnFileIsClean           ok      "none"
hostFunctionWithItsOwnFileIsClean   ok      "none"
importedFileWithoutHabitKeysIsQuiet ok      "none:imported+systemonly"
hostIsTheLastModule                 ok      "true"
aggregationModuleSitsJustBeforeTheHost ok   "host+aggregation+allhosts+systemonly"
hookDefaultsChangeNothing           ok      "same:true"
mkHostPassesTheModulesThrough       ok      "same:true"
wrapFunctionModule                  ok      "same:true:fn,home-manager,out,sys"
wrapAttrsModule                     ok      "same:true:home-manager,out,sys"
wrapOptionsAndConfigModule          ok      "same:true:home-manager,opt,out,sys"
wrapShorthandModule                 ok      "same:true:environment,home-manager,out,sys"
wrapFreeformTypeAndMeta             ok      "same:true:free,home-manager,meta,sys"
splitPlain                          ok      "sys=k:s home=k:h"
splitMkIf                           ok      "sys=k:s home=k:h"
splitMkIfFalseDropsBothHalves       ok      "sys= home="
splitMkMerge                        ok      "sys=a:1,b:2 home=a:x,b:y"
splitMkIfOfMkMerge                  ok      "sys=a:1,b:2 home=a:x"
splitMkOverride                     ok      "sys=k:s home=k:h"
leavesNeverForceACondition          ok      "if"
splitHabitUnderMkIf                 throws  lanes/habitIf.nix (habit module 'habitIf'): `habit` is a `if` value; write habit.home as a plain attribute
splitUnknownHabitKey                throws  lanes/habitTypo.nix (habit module 'habitTypo'): unknown habit key(s): homee; only `home` is read
splitConfigNotAttrs                 throws  lanes/nonAttrsConfig.nix (habit module 'nonAttrsConfig'): config must be an attribute set, got list
splitUnsplittableType               throws  lanes/orderConfig.nix (habit module 'orderConfig'): config is a `order` value habit cannot split
wrapKeyIsTheNameAndFileIsTheAuthors ok      "habit:ownFile authors/own-file.nix"
wrapKeepsTheModulesFormals          ok      "sys=k:supplied home="
wrapHomeWithoutAReaderIsNeverRead   ok      "sys=k:s home="
wrapHomeWithAReaderIsRead           throws  habit.home was read
wrapSystemOffAppliesNothingOfTheSystem ok   "sys= home=k:h"
wrapSystemOnImports                 throws  landmine/default.nix was imported
wrapSystemOffEmitsNoSystemOptions   ok      "sys= home=k:h"
wrapFreeformTypeSurvivesSystemOff   ok      "sys= home=k:h"
wrapSystemOnRefusesAnUndeclaredOption throws The option `nonexistent' does not exist
wrapNoHomeUserEmitsNothingWithoutHomeManager ok "sys=k:s home="
wrapHomeUserNeedsHomeManager        throws  The option `home-manager' does not exist
wrapNotAModule                      throws  lanes/notModule.nix (habit module 'notModule'): does not look like a module, got string
homeHalvesOfDifferentPrioritiesBothReachTheUser ok "sys= home=a:1,b:2"
homeNotAModuleIsRefusedForAUser     throws  lanes/homeNotAModule.nix (habit module 'homeNotAModule') `habit.home`: does not look like a module, got int
homeHalfMayBeAPath                  ok      "sys= home=k:p"
homeImportsApplyWhenNothingCoversThem ok    "sys= home=k:i"
homeImportsUnderAConditionAreRefused throws lanes/conditionedImports.nix (habit module 'conditionedImports') `habit.home`: carries `imports` or `options` under a condition; a condition covers only what the half sets, so move them out of it
homeOptionsUnderAConditionAreRefused throws lanes/conditionedOptions.nix (habit module 'conditionedOptions') `habit.home`: carries `imports` or `options` under a condition; a condition covers only what the half sets, so move them out of it
wrapUnsupportedTopLevelAttribute    throws  lanes/unsupportedAttr.nix (habit module 'unsupportedAttr'): has an unsupported top-level attribute: bogus; put configuration under `config`
splitHabitNotAttrs                  throws  lanes/habitNotAttrs.nix (habit module 'habitNotAttrs'): `habit` must be an attribute set holding `home`, got int
selectionKeyInsideADendriteIsRefused throws lanes/habitSelects.nix (habit module 'habitSelects'): unknown habit key(s): dendrites; only `home` is read
nestedImportedHabitHomeIsRefused    throws  The option `habit.home' does not exist
directPlain                         ok      "sys= home=k:h"
directMkIfFalseDropsTheHomeHalf     ok      "sys= home="
directMkIfFalseCoversEveryPartOfAMerge ok   "sys= home="
directMkMerge                       ok      "sys= home=a:x,b:y"
directMkIfOfMkMerge                 ok      "sys= home=a:x"
directMkOverride                    ok      "sys= home=k:h"
directMkIfOfMkOverride              ok      "sys= home=k:h"
directFunctionUnderMkIf             ok      "sys= home=k:H"
directFunctionUnderMkIfFalse        ok      "sys= home="
directHomeValueUnderMkIf            ok      "sys= home="
directHomeNotAModule                throws  lanes/homeNotAModule.nix (habit module 'homeNotAModule') `habit.home`: does not look like a module, got int
directHomeIsRead                    throws  habit.home was read
darwinAppliesTheSystemHalfAndRoutesTheHome ok "sys=dunst casks=kitty accounts=alice alice=dunst,homebrew"
darwinRefusesAnOptionItDoesNotHave  throws  The option `services' does not exist
darwinNamesTheModuleItRefuses       throws  dendrites/linuxOnly'
mkDarwinHostPassesTheModulesThrough ok      "same:true"
mkHomePassesTheModulesThrough       ok      "same:true:the caller's pkgs"
standaloneHomeDropsTheSystemLane    ok      "linuxOnly"
standaloneHomeAppliesTheHomeHalfOnly ok     "dunst"
standaloneHomeNeverImportsAnUnselectedModule ok 3
standaloneHomeImportsWhatItSelected throws  landmine/default.nix was imported
standaloneHomeSelectedIsItsOwnScope ok      "homeonly,notifications/mako"
standaloneHomeSelectedIsReadOnly    throws  The option `habit.selected' is read-only, but it's set multiple times
standaloneHomeSettingUsersIsRefused throws  hosts/homeSetsUsers.nix sets `habit.users`; a standalone home has no users, the host module is the home itself
standaloneHomeAggregationSelectsItsHomeHalf ok "dunst+aggregation"
standaloneHomeModulesKeepTheirPosition ok   "dunst,host,aggregation,homely"
standaloneHomeAppliesItsOverrideRecords ok  "matched=allhosts,homely overlays=2 marks=dunst,homely"
standaloneHomeSelectionModulesSeeTheHomeScope ok "scan=home platform=home"
standaloneHomeFailsTheAssertionForAnImportedSelection throws hosts/selectsSshInImport.nix but the host scan never saw it (scans do not follow `imports`)
unknownClassIsRefused               throws  unknown class 'frobnicate'; habit builds darwin, home, nixos
homeUserNeedsTheHomeManagerModule   throws  host 'fixture': user(s) alice have home.enable = true but no `homeManagerModule` was given
standaloneHomeTakesNoHomeManagerModule throws home 'alice' was given a `homeManagerModule`; a standalone home is evaluated by Home Manager itself and imports none
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
overlayOrder                        ok      "dendrite,dendrite,record,caller"
recordOverlayBeatsDendrite          ok      "record"
callerOverlayBeatsRecord            ok      "caller"
exampleMinimalInventory             ok      "box:ssh=ssh.nix"
exampleMinimalModules               ok      ["lambda","set{_class,_file,config,disabledModules,imports,key,options}","path"]
exampleMinimalConfig                ok      "box ssh=true"
exampleMinimalAssertionsHold        ok      "none"
realSystemFailsTheAssertionForAnImportedSelection throws hosts/selectsSshInImport.nix but the host scan never saw it (scans do not follow `imports`)
exampleWorkstationInventory         ok      "bluetooth alice=notifications/dunst"
exampleWorkstationModules           ok      ["lambda","set{_class,_file,config,disabledModules,imports,key,options}","set{_class,_file,config,disabledModules,imports,key,options}","set{_class,_file,config,disabledModules,imports,key,options}","set{home-manager,imports}","set{services}","path"]
exampleWorkstationConfig            ok      "desk bluetooth=true printing=false layout=de alice=true dunst=true mako=false"
exampleWorkstationSelected          ok      "sys=bluetooth alice=notifications/dunst"
exampleWorkstationSwitchedOffIsNeverImported ok 7
exampleWorkstationSwitchedBackOnIsImported throws landmine/default.nix was imported
exampleMergedInventory              ok      "dev:git,ssh,tmux"
exampleMergedModules                ok      ["lambda","set{_class,_file,config,disabledModules,imports,key,options}","set{_class,_file,config,disabledModules,imports,key,options}","set{_class,_file,config,disabledModules,imports,key,options}","path"]
exampleMergedConfig                 ok      "git=true ssh=true tmux=true"
exampleMergedClash                  throws  catalogue names defined by more than one source: 'ssh' by shared and upstream
exampleHomeInventory                ok      "alice:ssh=ssh.nix"
exampleHomeModules                  ok      ["lambda","set{_class,_file,config,disabledModules,imports,key,options}","path"]
exampleHomeConfig                   ok      "alice ssh=true"
exampleHomeSelected                 ok      "ssh"
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
