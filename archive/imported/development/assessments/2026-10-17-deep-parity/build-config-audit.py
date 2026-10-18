from pathlib import Path
import json, hashlib, importlib.util, contextlib, io

H = Path(__file__).resolve().parent
R = Path('/Users/nene/Documents/fpv-1')
T = R/'toolbox2_source/APPS/TOOLBOX2'
A = R/'radiomaster_tx16s_mkII/LUA/sdcard/SCRIPTS/TOOLS/telem.lua'
O = H.parent/'toolbox-200-reference/fm2m-toolbox-200-edgetx/FM2M/APPS/TOOLBOX2'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
spec = importlib.util.spec_from_file_location('dis53', H.parent/'toolbox-200-reference/disassemble53.py')
dis = importlib.util.module_from_spec(spec); spec.loader.exec_module(dis)
E = H/'config-evidence'; E.mkdir(exist_ok=True)
index = []
for p in sorted((O/'LIB/CFG').glob('*.luac')):
    parser = dis.Dump(p.read_bytes()); proto = parser.f(); assert parser.p == len(parser.raw)
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        print('Original file:', p); print('Original SHA256:', sha(p)); dis.dumpfun(proto)
    q = E/(p.stem+'.txt'); q.write_text(out.getvalue())
    index.append(dict(module=p.stem, originalFile=str(p), originalSha256=sha(p), disassembly=str(q), disassemblySha256=sha(q)))
(E/'module-index.json').write_text(json.dumps(index, indent=2)+'\n')
decls = json.loads((H/'toolbox-config-declarations.json').read_text())

# status, AERODECK counterpart, reference behavior, acceptance, main source line
M = {}
def put(key, status, aero, toolbox, acceptance, line=210):
    M[key]=(status,aero,toolbox,acceptance,line)

put('MDL_RCP','partial','rcProtocol saves a local profile; native reads and some MSP auto cases continue for None.','Protocol family activates its reader set and dependent capabilities; OFF clears model subfeatures.','Protocol selection must route real readers/defaults/units and OFF must have consistent documented effects.',211)
put('MDL_FC','partial','fcType selects visibility and a Betaflight-only MSP gate; INAV is listed but not implemented.','FC choice drives BF/INAV family setup and dependent screens.','Choose each supported family, then prove real decoder/transport and field visibility after save.',211)
put('MDL_BTV','partial','voltage has Auto/None/manual sensor; no grouped pack provider or automatic cell inference.','Battery sensor group selects native protocol readers.','Provider selection must distinguish flight pack from receiver supply and reset dependent state.',212)
put('MDL_BTA','partial','current/consumed/remaining are individually mapped with actual numeric consumers.','Current group activates current, consumed charge and remaining calculations.','Read each protocol current/capacity source correctly, preserving zero and provenance.',212)
put('MDL_GYRO','partial','Separate pitch/roll mappings; CRSF radians conversion is real, other family adapters incomplete.','Gyro group activates family-specific attitude decoders.','Degree/radian and BF/INAV/FrSky inputs produce the correct known physical poses.',212)
put('MDL_ACC','unverified','No separate acceleration source controls or X/Y/Z view.','Accelerometer row is declared but hidden; DATAINIT/CFGUPD force its model-enable state off. Independent toggle is not a proven usable feature.','Verify actual supported acceleration producer before exposing it; do not implement a decorative disabled toggle.',212)
put('MDL_BARO','missing','A note says NOT IMPLEMENTED; Alt is sampled as fallback into undifferentiated altitude.','Independent barometer group provides barometric altitude and vertical speed.','Enable/disable barometer data and preserve baro versus GPS origin in views.',212)
put('MDL_PITOT','missing','ASpd is sampled but has no configurable provider or adaptive Flight instrument.','Independent pitot group supplies airspeed.','Configure pitot source and display labelled airspeed with ground speed fallback/auxiliary.',212)
put('MDL_GPS','partial','GPS/manual source and None are real; local capture is page-owned and FC quality decoding incomplete.','GPS enable drives family readers, navigation data and optional detailed MSP poll.','Disable/enable GPS consistently and run acquisition independently of the selected page.',212)
put('MDL_VTX','missing','vtxMode only exposes local-reference lists, not a backend.','VTX enable activates actual connection/status/control functions; INAV model setup disables this BF VTX path.','Expose only supported backend capabilities and activate a genuine status/control path.',211)
put('RCP_pv','missing','Protocol version is an explanatory note saying configured in RF module.','Subtype/version selection changes reader definitions, RF captions and thresholds.','Support actual source subtype semantics; avoid confusing app decoder version with an RF firmware updater.',215)
for tk,ak,units in [('RL_RSI_L','rssiLow','RSSI'),('RL_RSI_C','rssiCrit','RSSI'),('RL_RQL_L','lqLow','LQ'),('RL_RQL_C','lqCrit','LQ'),('RL_SNR_L','snrLow','SNR'),('RL_SNR_C','snrCrit','SNR')]:
    put(tk,'partial',f'{ak} is saved and used; fixed dBm/%/dB ranges and defaults.','Protocol-aware defaults/ranges/units; unavailable LQ/SNR rows hidden for ACCST/R9.','Select ELRS, Crossfire and FrSky subtypes: validate units/defaults, low/critical ordering and unavailable fields.',215)
for tk,label in [('BT_CELL_NOPWR','no-power'),('BT_CELL_MIN','minimum'),('BT_CELL_CRIT','critical'),('BT_CELL_LOW','low'),('BT_CELL_MAX','maximum')]:
    put(tk,'partial',f'Actual {label} threshold in eight-field battery draft; 0.1V integer representation with ordered validation.','Seven-field battery editor has numeric ranges and neighboring boundary adjustment; defaults differ from AERODECK.','Save, reload and test exact boundaries in float32; document defaults and resolve invalid order without silent changes.',59)
put('BT_CELL_WARN_TYPE','equivalent','Visual, sound, haptic and both are implemented in batteryConfig.check.','Selectable alert modality is consumed by warning/sound handling.','Verify each modality on the target radio; no output when no pack power or muted.',168)
put('BT_CELL_WARN_SND','equivalent','Critical-only or critical+low policy is saved and consumed.','Separate low/critical audible policy.','Verify both policies at exact low/critical boundaries and after reconnect; cadence/mute are separate requirements.',168)
put('FC_MSP_ON','partial','mspMode Off/Auto controls read-only CRSF status client.','MSP activation routes transport and FC-family reader lifecycle.','Off stops requests; On initializes the selected family/transport without consuming other clients frames.',220)
put('FC_MSP_VER','equivalent','Actual supported wire client uses MSPv2; no misleading version editor.','Declared field is fixed to2 and hidden; not a free version selector.','Prove MSPv2 framing; do not add a dummy editable version control.',220)
put('FC_MSP_ERR_INTVAL','missing','Fixed three-second status interval note.','Editable status polling interval0..5seconds.','Provide bounded capability-aware status scheduling; define zero semantics and verify on wire.',220)
put('FC_MSP_VTX_INTVAL','missing','No VTX scheduler or edit.','Editable VTX interval0..10seconds, hidden for unsupported INAV path.','Schedule supported VTX reads with transport budgets and documented zero semantics.',220)
for prefix,subject,ak in [('_AR','Arm','armSource'),('_TC','Throttle cut','cutSource')]:
    put(prefix+'_srct','partial',f'{ak}: None,SA..SH,L01..L04; arm/cut are display indications only.',f'{subject} supports physical/logical sources; Arm additionally native telemetry; gates are licensing only.','Support all real source kinds without implying switch indication proves FC armed state.',222)
    put(prefix+'_swn','partial',f'Hard-coded SA..SH choices in {ak}.','Enumerates actual radio physical switches and display names.','Populate from supported radio inputs, preserving saved identity and unsupported-source diagnosis.',221)
    put(prefix+'_swp','partial','Low/centre/high positions only (-1/0/1).','up/mid/down/not-up/not-mid/not-down matching.','All six predicates work on two- and three-position switches and survive reload.',222)
    put(prefix+'_lsn','partial','L01..L04 only.','Logical switch1..64.','Bind each supported logical switch, including64, without pretending a missing source is false.',221)
put('_TL_srct','missing','No limiter source or live limiter percentage.','Pot/slider/trim source learning and normalized limiter indication.','Select real supported source by name/movement and show correct normalized limiter without changing outputs.',222)
put('_TMR_host','missing','App-local elapsed seconds is a distinct partial feature; no host selector.','OS or Toolbox-hosted arm timer.','Respect owner: read selected OS timer or manage app timer; define start/stop/reset across surfaces.',222)
put('_TMR_no','missing','No Timer1/2/3 selection or model.getTimer use.','Select one of three model timers.','Read/display/control the selected model timer with explicit reset actions.',222)
for prefix,mode in [('_FMAC','Acro'),('_FMHR','Horizon'),('_FMAN','Angle'),('_AM','Airmode'),('_TU','Turtle')]:
    for suffix,detail in [('srct','Off/physical/logical/telemetry source kind'),('swn','hardware switch'),('swp','six position predicates'),('lsn','logical switch1..64')]:
        put(prefix+'_'+suffix,'missing','One flightmode text source and explanatory notes; no independent per-mode binding.',f'{mode}: independent {detail}; subordinate rows depend on selected source kind.','Save and exercise this mode independently, then confirm telemetry/switch disagreement is presented honestly.',223)
put('VTX_CONN_TYPE','missing','Four notes, zero editable controls; no connection is activated.','None, FC MSP or native TBS receiver/VTX path.','Activate actual supported backend with status/reply dispatcher, disarmed guard and clear errors.',224)
put('VTX_MODEL','missing','No native TBS hardware map selection.','Eight native TBS hardware power maps, dependent on connection type.','Selected hardware map translates reported dBm and supported output levels without assuming every label is mW.',224)
put('VTX_PROXY_ON','missing','No UID-bound VTX table cache.','Optional per-FC proxy/cache using UID and SD data.','Load/refresh bounded data cache for current FC only; never execute an untrusted cache as Lua.',224)
put('VTX_FRQ_RANGE','unverified','No range filter.','ALL/EU/US value is saved, but no runtime frequency filter consumer was found in inspected package.','Do not claim working Toolbox range enforcement. If AERODECK offers a range setting, verify its actual filtering behavior independently.',224)
put('GPS_SATS2FIX','partial','homeSats4..64, autoHome separate; only GPS rendering calls home sampling.','Threshold1..64; CRSF path uses satellite count for local fix/home heuristic, not genuine FC fix.','Page-independent capture with explicit local/FC identity; genuine fix where available, no invented HDOP.',227)
put('APP_errLog','unverified','No optional on-radio diagnostic error logger; diagnostics are on-screen.','CFGAPP declares APP_errLog while runtime/save use APP_LOG_ERR; numeric0 is truthy. Writer exists; user toggle appears defective in original.','Implement an explicit bounded diagnostic logger with a working opt-in/off switch; do not copy case/truthiness bug.',228)

rows=[]
def evidence(module,line,aero_line):
    original=O/'LIB/CFG'/(module+'.luac'); recovered=T/'LIB/CFG'/(module+'.lua'); dump=E/(module+'.txt')
    return [dict(file=str(recovered),line=line,kind='recovered-source-declaration',sha256=sha(recovered)),dict(file=str(dump),line=1,kind='original-bytecode-disassembly',sha256=sha(dump),originalFile=str(original),originalSha256=sha(original)),dict(file=str(A),line=aero_line,kind='production-source',sha256=sha(A))]
def row(module,key,label,line,entry,generated=False):
    status,aero,tb,accept,al=entry
    n=len(rows)+1
    rows.append(dict(id=f'CFG-{n:03d}',area='Configuration / '+module,feature=key+' — '+label,toolbox=tb,aerodeck=aero,status=status,evidence=evidence(module,line,al),dependencies=['Shared data/capability store','Validated per-model persistence'],userImpact='A list title or saved value is insufficient; its runtime behavior must exist.',acceptance=accept,priority='P1',confidence='medium' if status=='unverified' else 'high',referenceField=key,generatedField=generated,requiredForReplacement=status!='unverified',hardwareVerified=False))
for mod in decls:
    for f in mod['fields']:
        assert f['key'] in M,f['key']
        row(mod['module'],f['key'],f['label'],f['sourceLine'],M[f['key']])
    if mod['module']=='CFGBFV':
        for i in range(1,6):
            row('CFGBFV',f'_f{3*i-2}',f'Pack{i} enable/chemistry',18,('missing',f'Pack{i} always exists; no enabled/chemistry state.','Each favourite is OFF or a battery type; subordinate cell/capacity rows hide when OFF.','Disable/enable a favourite, select chemistry, persist it, and ensure chooser shows only usable entries.',217),True)
            row('CFGBFV',f'_f{3*i-1}',f'Pack{i} cell number',28,('partial',f'cells{i},1..12; actually used in pack voltage calculations.','Cell count1..99 associated with enabled favourite.','Preserve valid required counts and enforce supported target limits explicitly; apply selected profile consistently.',218),True)
            row('CFGBFV',f'_f{3*i}',f'Pack{i} capacity',29,('partial',f'capacity{i},100..30000mAh in50mAh steps; real remaining calculation.','Capacity100..100000mAh in50mAh steps.','Support required capacity range without overflow; selected profile drives remaining with provenance.',218),True)
    if mod['module']=='CFGVFV':
        for i in range(1,9):
            row('CFGVFV',f'_f{i}',f'Favourite channel{i}',36,('partial',f'vtx{i}: manual5000..6000MHz frequency note; noOFF/table-membership/apply.','OFF0 or channel chosen from actual frequency table; saved frequency used by dashboard apply.','Disable, save, reload, choose a table channel and confirm real readback after explicit apply.',226),True)
    if mod['module']=='CFGUI':
        row('CFGUI','_theme','Theme',16,('partial','Three accents; fixed dark palette.','Selectable full palette/theme family with resolution layouts.','Provide readable full contrast theme choices; exact carbon/leather textures are not required.',228),True)
        row('CFGUI','_ov','Draw GFX overlay',24,('equivalent','Procedural flat design intentionally omits decorative full-screen overlays.','Optional decorative overlay independent of functional data.','Keep core information legible with optional imagery absent; no requirement to reproduce unwanted carbon texture.',228),True)
assert len(rows)==90,len(rows)

def workflow(id,feature,tb,aero,status,accept,line=231):
    rows.append(dict(id=id,area='Configuration / workflow',feature=feature,toolbox=tb,aerodeck=aero,status=status,evidence=evidence('CFGUPDP',7,line),dependencies=['Stable capability IDs','Config persistence'],userImpact='Settings must predict the application behavior and preserve user work.',acceptance=accept,priority='P1',confidence='high',requiredForReplacement=True,hardwareVerified=False))
workflow('CFG-X01','Conditional list visibility','Four base lists; protocol/model/backend flags enable dependent lists. Activation gates are excluded from AERODECK.','Four base lists implemented; independent voltage/gps/vtx/family conditions expand to12. Some shown lists are notes only.','partial','Exercise the full capability truth table; show supported controls and explain unavailable features, not dummy lists.')
workflow('CFG-X02','Dependent field visibility','Indicator source kind, enabled pack, family and protocol subtype hide irrelevant rows.','Some lists gated but source-kind/pack-type dependent rows and backend selectors are absent.','partial','Change every parent setting, verify rows and focus remain valid, and preserve inactive values for later reuse.',312)
workflow('CFG-X03','Save activates backend lifecycle','Model save queues DATAINIT/FCINIT/RCPINIT/GPSINIT/TLMINIT/MSPINIT/VTXINIT/MDUPD/CFGUPDP.','Save replaces active settings; some startup properties require reopen; notes have no consumer.','partial','Track every setting to a real consumer; apply without destructive resets and state clearly when restart is needed.',288)
workflow('CFG-X04','Per-model data persistence','ModelID+name path; serializes Lua configuration.','Plain ADCFG1/ADBAT1 data, model-name hex filename, verified writes and previous active backup.','partial','Prove duplicate names/rename/model switch behavior, malformed/truncated main/backup recovery and no cross-model settings leak.',279)
workflow('CFG-X05','Explicit draft/save/revert/exit recovery','Configuration editor commits its values and reinitializes dependent modules.','Draft isolation, per-value cancel, Save/Revert and dirty-exit modal are genuine improvements.','addition','Every touch/rotary/PAGE/RTN route preserves or explicitly discards the correct app and battery drafts.',288)
workflow('CFG-X06','Live sensor picker refresh','Source registry/input enumeration updates available choices.','Real refresh exists, but duplicate flightmode schema declaration leaves Model Setup row stale.','partial','Use fixture CustomFM then LateFM: both Model Setup and BF Indicators pickers must receive identical refreshed choices.',273)
workflow('CFG-X07','Single owner for shared settings','Serialized setting domains have reinit consumers.','mspMode appears inFC andApp using the same object; flightmode is recreated, leaving first object detached.','partial','Give each setting one canonical object; all views share value, validation and choices without duplicate schema overwrite.',223)
workflow('CFG-X08','Validation beyond type/range','Protocol choices and value dependencies constrain valid configurations.','Numeric/order and source-line validation exists; enum-like strings are broadly accepted as strings.','partial','Reject unsupported enum values; retain unresolved manual sensor names with explicit diagnosis; version and migrate settings.',249)
workflow('CFG-X09','All twelve sections correspond to working capabilities','Most fields have actual runtime consumers; several reference declarations are hidden/dead or defective and explicitly flagged.','FC has1editable+4notes; VTX0editable; BF Indicators1editable+3notes; App1sharededitable+6notes.','partial','A section cannot be declared complete until every offered action has a working end-to-end outcome.',220)
workflow('CFG-X10','Source changes reset only owned history','New-flight reset and provider/session initialization have explicit paths.','Some trace/home state can survive changed source identity; no unified reset contract.','partial','Change model/source/profile and verify only dependent history/home/session state resets, with user-visible ownership.',273)
(H/'config-rows.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'fieldRows':90,'workflowRows':len(rows)-90,'allRows':len(rows)},indent=2))
