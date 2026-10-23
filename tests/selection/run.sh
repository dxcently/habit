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
switchedOffMemberIsNeverImported    ok      "fixture"
switchedOnMemberIsImported          throws  landmine/default.nix was imported
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
hostSystemOffReachesEveryHomeUserAndAppliesNoSystemHalf ok "sys= alice=dunst bob=dunst"
userSystemOffReachesThatUserAndAppliesNoSystemHalf ok "sys= alice=dunst bob="
hostSystemOffAndAUserSystemOnApplyTheSystemHalfOnce ok "sys=dunst alice=dunst bob=dunst"
userSystemOffAndAnotherUserSystemOnApplyTheSystemHalfOnce ok "sys=dunst alice=dunst bob=dunst"
everySelectionSystemOffAppliesNoSystemHalfAndTheHomeHalfOnce ok "sys= alice=dunst bob=dunst"
systemOffOfADisabledSelectionChangesNothing ok "sys=dunst alice=dunst"
systemOffEverywhereNeverImportsTheSystemHalf ok "sys= alice=splitlandmine"
systemOnByOneSelectionImportsTheSystemHalf throws landmine/default.nix was imported
aggregationMemberSystemOffByTheHost ok      "sys=systemonly alice=dunst"
userAggregationMemberSystemOffByTheUser ok  "sys= alice=dunst"
systemOffByTheHostOnAModuleWithoutAHomeHalfIsRefused throws dendrites/systemonly/default.nix (habit module 'systemonly'): host 'fixture' `habit.dendrites.systemonly.system = false` selects only the home half of 'systemonly', which has none
systemOffByAUserOnAModuleWithoutAHomeHalfIsRefused throws dendrites/systemonly/default.nix (habit module 'systemonly'): user 'alice' of host 'fixture' `habit.users.alice.dendrites.systemonly.system = false` selects only the home half of 'systemonly', which has none
systemOffOnAProviderWithoutAHomeHalfIsRefused throws dendrites/systemonly/default.nix (habit module 'choice'): host 'fixture' `habit.dendrites.choice.system = false` selects only the home half of 'choice', which has none
systemOffOnAProviderWithAHomeHalfIsApplied ok "sys= alice=homeonly"
hostSystemOffWithoutHomeUsersIsRefused throws host 'fixture': `habit.dendrites.notifications.system = false` selects only the home half of 'notifications' but no user has home.enable
hostSystemOffWithOnlyUsersWithoutHomeManagerIsRefused throws host 'fixture': `habit.dendrites.notifications.system = false` selects only the home half of 'notifications' but no user has home.enable
inventoryShowsEachSelectionsSystem  ok      "host=false alice=true"
overrideSystemModuleAppliesWhenTheTargetsSystemHalfDoes ok "system=1 overlays=1 alice=1"
overrideSystemModuleIsWithheldFromATargetSelectedAsHomeOnly ok "system=0 overlays=1 alice=1"
overrideSystemModuleAppliesWhenOneSelectionOfTheTargetAsksForTheSystemHalf ok "system=1 overlays=1 alice=1"
standaloneHomeAcceptsSystemOff      ok      "dunst"
standaloneHomeAcceptsSystemOffOnAModuleWithoutAHomeHalf ok ""
systemInAnImportedFileFailsAnAssertion throws `habit.dendrites.systemonly.system` is set in
systemInAnInlineImportIsCaughtByItsValue throws `habit.dendrites.systemonly.system` is set in
userPickBeatsHostForItsHome         ok      "sys=dunst alice=herald bob=dunst"
oneLineProviderSelects              ok      "sys=herald alice=herald"
oneLineHomeOnlyProvider             ok      "sys= alice=mako"
sameProviderAsHostIsOneApplication  ok      "sys=dunst alice=dunst bob=dunst"
userGroupPickBeatsHostGroupForItsHome ok    "sys=dunst alice=mako bob=dunst"
homeOnlyUserLetsAnotherProviderHoldTheSystemHalf ok "sys=dunst alice=mako bob=dunst"
explicitSystemForAnotherProviderIsRefused throws user 'alice' sets `habit.users.alice.dendrites.notifications.system = true` with provider 'herald', but the host holds the system half of 'notifications' with 'dunst'; one system takes one implementation
providerWithEnableOffIsRefused      throws  user 'alice', dendrite 'notifications': `habit.users.alice.dendrites.notifications` sets provider 'herald' and enable = false
autoHomeOnlyWithoutAHomeHalfIsRefused throws selects only the home half of 'choice', which has none
userGroupPickWithGroupOffIsRefused  throws aggregation 'desk': `habit.users.alice.aggregation.desk.notifications` sets provider 'mako' and enable = false
userEnabledWithoutProviderTakesTheHostsProvider ok "sys=dunst alice=dunst bob=dunst"
userEnabledWithoutProviderAndNoHolderIsRefused throws dendrite 'notifications' is enabled but chose no provider
hostSystemOffUserEnabledTakesHostProvider ok "sys=dunst alice=dunst bob=dunst"
hostSystemOffUserPickIsHomeOnly     ok      "sys= alice=herald bob=dunst"
hostSystemOffUserExplicitSystemTakesIt ok   "sys=herald alice=herald bob=dunst"
hostUnselectedUserPickTakesTheSystemHalf ok "sys=herald alice=herald"
homeWithoutUsersNamesAnotherProvider throws every user with home.enable opts out of it or names another provider of it
homeOnlyHostWithAUserWithoutAHomeHalfIsRefused throws selects only the home half of 'choice', which has none
wrappedSystemWhereItMattersIsRefused throws is written under a wrapper (mkIf, mkForce or mkMerge) above it
wrappedUsersWithTheHostsProviderAreFine ok "sys=dunst alice=dunst"
userDirectPickBeatsOwnGroupPick     ok      "sys=herald alice=herald"
providerKeysFollowTheHolder         ok      true
hostSentMemberIsNotAHostSelection   ok      "false"
unnamedThirdProviderIsNeverImported ok      "dunst+herald"
chosenThirdProviderIsImported       throws  notifications/landmine.nix was imported
selectedPerScope                    ok      "host=dunst alice=herald bob=none"
inventoryPerUser                    ok      "host=dunst alice=herald"
overrideHomeRidesEachUsersProvider  ok      "alice=herald+notify bob=dunst+notify"
usersWithDifferentProvidersAreRefused throws dendrite 'notifications' is wanted with different providers for its system half (user 'alice': 'mako'; user 'bob': 'dunst'); one system takes one implementation. Either set `habit.users.<u>.dendrites.notifications.system = false` on one so it lives in that user's home only, or, if both need the system half, they are not alternatives: make them two dendrites
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
splitMkIfFalseNeverDefinesAnUndeclaredOption ok "sys= home="
splitMkIfOfMkMergeFalseNeverDefinesAnUndeclaredOption ok "sys= home="
splitMkIfOnTheHomeValueFalseNeverDefinesAnUndeclaredOption ok "sys= home="
splitMkIfOfMkOverrideFalseNeverDefinesAnUndeclaredOption ok "sys= home="
splitMkIfTrueAppliesOnAStrictPlatform ok    "sys=k:s home=k:h"
splitMkIfOfMkOverrideKeepsThePriority ok    "sys= home=k:h"
splitMkIfFalseWithADeclaredOptionAppliesNothing ok "sys= home="
splitMkIfOfMkMerge                  ok      "sys=a:1,b:2 home=a:x"
splitMkOverride                     ok      "sys=k:s home=k:h"
leavesNeverForceACondition          ok      "if"
splitHabitUnderMkIf                 throws  lanes/habitIf.nix (habit module 'habitIf'): `habit` is a `if` value; write habit.home as a plain attribute
splitUnknownHabitKey                throws  lanes/habitTypo.nix (habit module 'habitTypo'): unknown habit key(s): homee; only `home` is read
splitConfigNotAttrs                 throws  lanes/nonAttrsConfig.nix (habit module 'nonAttrsConfig'): config must be an attribute set, got list
splitUnsplittableType               throws  lanes/orderConfig.nix (habit module 'orderConfig'): config is a `order` value habit cannot split
splitErrorNamesTheFileOfADirectoryEntry throws lanes/directoryEntry/default.nix (habit module 'directoryEntry'): unknown habit key(s): homee
wrapFileOfADirectoryEntryIsItsDefaultNix ok "/lanes/directoryEntry/default.nix"
wrapKeyIsTheNameAndFileIsTheAuthors ok      "habit:ownFile authors/own-file.nix"
wrapKeepsTheModulesFormals          ok      "sys=k:supplied home="
wrapHomeWithoutAReaderIsNeverRead   ok      "sys=k:s home="
wrapHomeWithAReaderIsRead           throws  habit.home was read
wrapSystemOffAppliesTheHomeHalfAlone ok     "sys= home=k:h"
wrapSystemOffWithoutAHomeHalfIsRefused throws lanes/systemOnly.nix (habit module 'systemOnly'): the host selects only the home half of 'systemOnly', which has none
wrapSystemOffNeverReadsTheHomeHalfItChecks ok "sys= home="
wrapSystemOffNeverForcesAConditionItChecks ok "sys= home="
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
homeImportsUnderAConditionApplyForAUser ok  "sys= home=k:i"
homeOptionsUnderAConditionAreDeclaredForAUser ok "x"
homeImportsUnderAConditionAreRefused throws lanes/conditionedImports.nix (habit module 'conditionedImports') `habit.home`: carries `imports` or `options` under a condition; a condition covers only what the half sets, so move them out of it
homeOptionsUnderAConditionAreRefused throws lanes/conditionedOptions.nix (habit module 'conditionedOptions') `habit.home`: carries `imports` or `options` under a condition; a condition covers only what the half sets, so move them out of it
wrapUnsupportedTopLevelAttribute    throws  lanes/unsupportedAttr.nix (habit module 'unsupportedAttr'): has an unsupported top-level attribute: bogus; put configuration under `config`
splitHabitNotAttrs                  throws  lanes/habitNotAttrs.nix (habit module 'habitNotAttrs'): `habit` must be an attribute set holding `home`, got int
selectionKeyInsideADendriteIsRefused throws lanes/habitSelects.nix (habit module 'habitSelects'): unknown habit key(s): dendrites; only `home` is read
nestedImportedHabitHomeIsRefused    throws  The option `habit.home' does not exist
directPlain                         ok      "sys= home=k:h"
directMkIfFalseDropsTheHomeHalf     ok      "sys= home="
directMkIfFalseStillDefinesAnUndeclaredOption throws The option `undeclared' does not exist
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
darwinNamesTheModuleItRefuses       throws  dendrites/linuxOnly/default.nix'
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
step1Selected                       ok      "shell"
step1Config                         ok      "desk zsh=true shell=zsh"
step1AssertionsHold                 ok      "none"
step2Selected                       ok      "shell"
step2Alice                          ok      "sys=true alice=true ll=ls -l"
step3Selected                       ok      "shell/zsh"
step3Config                         ok      "sys=true fish=false alice=true"
step3UnchosenFileIsNeverRead        ok      "built"
step3UnchosenValueIsNeverApplied    ok      "built"
step3ChosenFileIsRead               throws  landmine/default.nix was imported
step4Selected                       ok      "shell/zsh"
step4Homes                          ok      "sys=true sysFish=false aliceZsh=false aliceFish=true bob=false"
step4AliceSelects                   ok      "shell/fish"
step5Desk                           ok      "shell/zsh,terminal/kitty"
step5Kitty                          ok      "alice=fish bob=none"
step6Desk                           ok      "shell/zsh,terminal/kitty"
step6Server                         ok      "shell/zsh"
step6BareHost                       ok      "overrides=0"
step7Desk                           ok      "1 alice=true"
fullDesk                            ok      "git,shell/zsh,ssh,terminal/kitty,tmux git=true tmux=true"
fullWithoutDevHasNoGit              ok      "git=false tmux=false"
fullHomes                           ok      "alice=zsh bob=none"
fullServer                          ok      "shell/zsh,ssh"
fullStandalone                      ok      "shell/fish,ssh fish=true"
fullClash                           throws  catalogue names defined by more than one source: 'ssh' by core and upstream
realSystemFailsTheAssertionForAnImportedSelection throws hosts/selectsSshInImport.nix but the host scan never saw it (scans do not follow `imports`)
sharedBareHomeIsRefused             throws  is already declared
sharedInlineSystemIsRefused         throws  is already declared
valueAttrsEntryApplies              ok      "sys=attrs"
valueFunctionEntryApplies           ok      "sys=function"
valueUnselectedEntriesAreInert      ok      "sys="
valueSelectedFunctionIsApplied      throws  applied
valueSelectedConfigIsRead           throws  config forced
valueHomeHalfReachesTheUser         ok      "sys= alice=home"
valuePathStringEntryApplies         ok      "sys= alice=homeonly"
valueInventoryNamesItsFile          ok      "values/attrsWithFile.nix"
valueInventoryNamesItsName          ok      "<value 'attrsValue'>"
valueErrorNamesTheEntry             throws  catalogue value 'badValue' (habit module 'badValue'): unknown habit key(s): homee
valueErrorNamesItsFile              throws  values/badFile.nix (habit module 'badFile'): unknown habit key(s): homee
providerValueSetChoosesAPath               ok      "sys=alpha alice=alpha"
providerValueSetChoosesAValue              ok      "sys=beta alice=beta"
providerValueSetNeedsAProvider             throws  dendrite 'providerSet' is enabled but chose no provider; available providers: dunst
providerValueSetUnknownProvider            throws  dendrite 'mixedSet' has no provider 'nope'; available providers: alpha, beta
providerValueSetUnselectedIsNotRead        ok      "sys=alpha"
providerUnchosenTargetsAreNotRead          ok      "sys=alpha"
providerChosenValueIsRead                  throws  chosen provider value was read
providerValueSetWithExtraKeyIsRefused      throws  dendrite 'extraKey': a provider set takes only `providers`; it also has config
providerFileSetWithExtraKeyIsRefused       throws  dendrite 'fileExtra': a provider set takes only `providers`; it also has fixture
providerSetNotASetIsRefused                throws  dendrite 'listProviders': `providers` is a list, not an attrset of provider targets
providerTargetNotAPathOrValueIsRefused     throws  dendrite 'numberTarget' provider 'num' is a int; a provider is a path or a module value
providerNestedSetIsRefused                 throws  dendrite 'nestedSet' provider 'inner' is a provider set; a provider is a path or a module value
providerValueTargetErrorNamesIt            throws  catalogue value 'badTarget.bad' (habit module 'badTarget'): unknown habit key(s): homee
providerFileSetChoosesAValue               ok      "sys=valued alice=valued"
providerFileSetChoosesAPath                ok      "sys=alpha"
providerInventoryNamesAValueTarget         ok      "<value 'mixedSet.beta'>"
providerInventoryNamesThePathTargetsSet    ok      "<value 'mixedSet'>"
providerInventoryNamesTheFileSet           ok      true
inventoryNeverImportsASelectedFile         ok      true
valueNotAModuleIsRefused            throws  option `habit.catalogue.notAModule' is not of type `a path, an attrset module or a function module'
mergeRegistriesValueEntriesMerge    ok      "sys=attrs"
mergeRegistriesValueClash           throws  catalogue names defined by more than one source: 'attrsValue' by alpha and beta
valueOutPathEntryIsAPath            ok      "sys= alice=homeonly"
valueOutPathEntrySourceIsItsFile    ok      true
valueFunctionReceivesModuleArgs     ok      "sys=fixture"
valueSameValueTwiceAppliesTwice     ok      "sys=dup+dup"
valueStandaloneHomeReceivesTheHomeHalf ok   "home"
valueImportingAHabitKeyIsRefused    throws  but the host scan never saw it
valueUnselectedAttributesAreNotForced ok    "sys="
valueThrowingEntryIsReadOnRead      throws  entry read
hostSentSystemHalfSurvivesADendriteOptOut ok "sys=systemonly alice="
hostSentSystemHalfSurvivesAGroupOptOut ok "sys=systemonly alice="
hostSentSystemHalfWithoutHomeUsers ok "sys=systemonly"
hostSentMemberReachesAUserWithoutOptOut ok "sys=systemonly alice="
userSelectedGroupMemberSystemHalfIsUnchanged ok "sys=systemonly alice="
hostSentMemberSystemOffIsRefused throws  selects only the home half of 'systemonly', which has none
householdHomeHalfReachesEveryHomeUser ok "sys=systemonly alice=household+homeonly bob=household+homeonly"
householdHomeHalfSkipsAUserWithoutHome ok "sys=systemonly alice=household+homeonly"
hostAndUserSelectingAGroupApplyItOnce ok "sys=systemonly alice=household+homeonly"
hostGroupHomeProviderReachesTheUser ok "sys=dunst alice=dunst"
userChoosesProviderForHostGroup ok "sys=dunst alice=mako"
userOptsOutOfHostGroup ok "sys=systemonly alice= bob=household+homeonly"
userOptOutOfGroupKeepsAHostDendrite ok "sys=systemonly alice=homeonly"
userOptsOutOfAGroupsHomeMemberDendrite ok "sys=systemonly alice=household bob=household+homeonly"
userOptsOutOfHostDendrite ok "sys=dunst alice= bob=dunst"
userOptsOutOfADendriteBroughtByAGroup ok "sys=systemonly+dunst alice= bob=dunst"
userOptOutOfNeverReachedDendriteIsRefused throws  user 'alice' opts out of dendrite 'notifications', which never reached it
userOptOutOfNeverReachedGroupIsRefused throws  user 'alice' opts out of aggregation 'household', which never reached it
userOptOutInAnInlineImportIsCaught throws  `habit.users.alice.dendrites.notifications.enable` is set in
unselectedGroupValueIsInert ok "sys=systemonly"
selectedGroupValueIsRefused throws  aggregation 'valued' is a set, not a path
overrideValueIsRefused throws  override record 'badRecord' is a set, not a path
ruleNeedsMetOnTheSystem             ok      "sys=systemonly"
ruleNeedsNotSelectedIsRefused       throws  host 'fixture' (system): dendrite 'systemonly' needs 'homeonly', which is not selected for the system
ruleNeedsSwitchedOffNamesTheLine    throws  dendrite 'systemonly' needs 'homeonly', which is switched off (`habit.dendrites.homeonly.enable = false`)
ruleReportsEveryUnmetNeed           throws  needs 'homeonly', which is not selected for the system; host 'fixture' (system): dendrite 'systemonly' needs 'notifications', which is not selected for the system
ruleNeedsNotCheckedWhenNotSelected  ok      "sys="
ruleNeedsMetByTheHostForAHome       ok      "sys= alice=mako+homeonly"
ruleNeedsMetByTheHomeItself         ok      "sys= alice=mako+homeonly"
ruleNeedsNotReachingAHomeIsRefused  throws  host 'fixture' (user 'alice'): dendrite 'notifications' needs 'homeonly', which is neither selected on the host nor reaches 'alice'
ruleNeedsSwitchedOffForAUserLeansOnTheSystem ok "sys= alice=mako"
ruleNeedsSwitchedOffForAUserIsRefused throws which is switched off for 'alice' (`habit.users.alice.dendrites.homeonly.enable = false`)
ruleNeedsSwitchedOffOnTheHostIsRefusedForAHome throws which is switched off on the host (`habit.dendrites.homeonly.enable = false`) and does not reach 'alice'
ruleNeedsAcrossMergedRegistriesMet  ok      "sys=systemonly"
ruleNeedsAcrossMergedRegistriesRefused throws host 'fixture' (system): dendrite 'systemonly' needs 'homeonly', which is not selected
ruleNamesTheRegistryItCameFrom      throws  rule 'nope' (from registry 'gamma') names no catalogue entry
ruleHostsAllowsTheListedHost        ok      "sys=systemonly"
ruleHostsRefusesAnotherHostDirectly throws  dendrite 'systemonly' is selected on host 'fixture' (directly), but its rule allows only host(s) beta
ruleHostsRefusesAGroupSelection     throws  dendrite 'systemonly' is selected on host 'fixture' (via aggregation 'household'), but its rule allows only host(s) beta
ruleHostsRefusesAUserSelection      throws  dendrite 'notifications' is selected on host 'fixture' (by user 'alice'), but its rule allows only host(s) beta
ruleHostsNotSelectedHereIsNotRefused ok     "sys="
ruleHostsNamesAnUnknownHost         throws  rule 'systemonly' is confined to unknown host(s): gamma
ruleHomesRefusesTwoUsers            throws  host 'fixture': dendrite 'systemonly' reaches the homes of 2 users (alice, bob), but its rule allows 1; switch off all but 1 with `habit.users.<u>.dendrites.systemonly.enable = false` for each of bob
ruleHomesCountsOnlyTheUsersReached  ok      "sys=systemonly alice= bob="
ruleHomesStandaloneCountsAsOne      ok      "desk"
ruleStandaloneHomeNeedsAreChecked   throws  host 'desk' (system): dendrite 'systemonly' needs 'homeonly', which is not selected
ruleUnknownFieldIsNamed             throws  rule 'systemonly' has unknown field(s): need; a rule takes only needs, hosts, homes
ruleForAnUnknownEntryIsNamed        throws  rule 'nope' names no catalogue entry; a rule is keyed by a catalogue name
ruleNeedingAnUnknownEntryIsNamed    throws  rule 'systemonly' needs unknown dendrite(s): nope; every need must be a catalogue name
ruleEmptyNeedsIsNamed               throws  rule 'systemonly': `needs` is empty; drop it or name a dendrite
ruleEmptyHostsIsNamed               throws  rule 'systemonly': `hosts` is empty; drop it or name a host
ruleHomesBelowOneIsNamed            throws  rule 'systemonly': `homes` must be a positive integer, got 0
ruleHomesNotAnIntIsNamed            throws  rule 'systemonly': `homes` must be a positive integer, got a string
ruleNeedsNotAListIsNamed            throws  rule 'systemonly': `needs` is a string, not a list of catalogue names
ruleHostsNotAListIsNamed            throws  rule 'systemonly': `hosts` is a string, not a list of host names
ruleNotAnAttrsetIsNamed             throws  rule 'systemonly' is a list, not an attrset; a rule takes only needs, hosts, homes
ruleOnAnUnselectedEntryNeverImportsIt ok    "sys=systemonly"
ruleOnASelectedEntryStillImportsIt  throws  landmine/default.nix was imported
emptyRulesChangeNothing             ok      "sys=systemonly"
ruleShowsInTheInventory             ok      ["homeonly"]
ruleAbsentFromAnUnruledEntry        ok      false
ruleAppliesWhateverTheProvider      throws  dendrite 'notifications' is selected on host 'fixture' (directly), but its rule allows only host(s) beta
ruleHostsNamesAStandaloneHome       throws  dendrite 'systemonly' is selected on host 'desk' (directly), but its rule allows only host(s) beta
ruleClashAcrossRegistries           throws  rules names defined by more than one source: 'systemonly' by gamma and delta
ruleHomeOnlyNeedDoesNotMeetASystemNeed throws host 'fixture' (system): dendrite 'systemonly' needs 'homeonly', which is not selected for the system
ruleSystemSwitchUnderMkForceIsNotCited throws host 'fixture' (system): dendrite 'systemonly' needs 'homeonly', which is not selected for the system
ruleUserSwitchUnderMkForceIsNotCited throws host 'fixture' (user 'alice'): dendrite 'notifications' needs 'homeonly', which is neither selected on the host nor reaches 'alice'
ruleHostGroupHomeMemberIsViaTheGroup throws dendrite 'homeonly' is selected on host 'fixture' (via aggregation 'household'), but its rule allows only host(s) beta
ruleHostGroupHomeMemberWithoutAUserIsRefused throws dendrite 'homeonly' is selected on host 'fixture' (via aggregation 'household'), but its rule allows only host(s) beta
ruleUserGroupNamesItsGroup          throws  dendrite 'notifications' is selected on host 'fixture' (by user 'alice' via aggregation 'desk'), but its rule allows only host(s) beta
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
