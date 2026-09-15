const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.join(__dirname, '..');
const context = vm.createContext({Date, JSON});
vm.runInContext(fs.readFileSync(path.join(root, 'services/CodexClient.js'), 'utf8'), context);
const plain = x => JSON.parse(JSON.stringify(x));
function fixture() {
    const wire = [], events = [];
    const c = new context.Client(m => wire.push(plain(m)), e => events.push(plain(e)), '/workspace');
    const take = method => {
        const i = wire.findIndex(m => m.method === method);
        assert.notEqual(i, -1, `Expected ${method}: ${JSON.stringify(wire)}`);
        return wire.splice(i, 1)[0];
    };
    const reply = (m, result) => c.receive({id:m.id, result});
    const notify = (method, params={}) => c.receive({method, params:{threadId:c.thread, turnId:c.turn, ...params}});
    function connect() {
        c.connected(); reply(take('initialize'), {}); take('initialized');
        reply(take('model/list'), {data:[]});
    }
    function start(model='', turn='turn-1') {
        c.send('Hello', model);
        if (!c.loaded) reply(take(c.thread ? 'thread/resume' : 'thread/start'), {thread:{id:'thread-1'},model:'configured'});
        const request = take('turn/start'); reply(request, {turn:{id:turn}});
        return request;
    }
    return {c,wire,events,take,reply,notify,connect,start};
}

test('queues input until initialization and thread creation are acknowledged', () => {
    const f=fixture();
    assert.equal(f.c.send('hello','chosen'),true); assert.equal(f.wire.length,0);
    f.c.connected(); assert.deepEqual(f.wire.map(m=>m.method),['initialize']);
    f.reply(f.take('initialize'),{}); f.take('initialized');
    const thread=f.take('thread/start');
    assert.equal(thread.params.cwd,'/workspace');
    assert.equal(thread.params.sandbox,'workspace-write');
    assert.equal(thread.params.approvalPolicy,'on-request');
    assert.equal(f.wire.some(m=>m.method==='turn/start'),false);
    f.reply(thread,{thread:{id:'thread-1'},model:'configured'});
    assert.equal(f.take('turn/start').params.model,'chosen');
});

test('applies model changes and restores the configured default in the same thread', () => {
    const f=fixture(); f.connect(); f.start('chosen');
    f.notify('turn/completed',{turn:{id:'turn-1',status:'completed'}});
    const next=f.start('', 'turn-2');
    assert.equal(next.params.model,'configured'); assert.equal(next.params.threadId,'thread-1');
    assert.equal(f.wire.some(m=>m.method==='thread/start'),false);
});

test('refuses empty input and overlapping turns', () => {
    const f=fixture(); assert.equal(f.c.send(' '),false);
    f.connect(); f.start(); assert.equal(f.c.send('another'),false);
});

test('streams assistant text and emits authoritative final item', () => {
    const f=fixture(); f.connect(); f.start();
    f.notify('item/agentMessage/delta',{itemId:'m',delta:'partial'});
    f.notify('item/completed',{item:{type:'agentMessage',id:'m',text:'complete'}});
    assert.deepEqual(f.events.slice(-2),[{type:'delta',id:'m',text:'partial'},{type:'message',id:'m',text:'complete'}]);
});

test('maps command output, failures, file diffs and MCP errors', () => {
    const f=fixture(); f.connect(); f.start();
    f.notify('item/started',{item:{type:'commandExecution',id:'cmd',command:'false',cwd:'/workspace',status:'inProgress'}});
    f.notify('item/commandExecution/outputDelta',{itemId:'cmd',delta:'output'});
    f.notify('item/completed',{item:{type:'commandExecution',id:'cmd',command:'false',exitCode:1,aggregatedOutput:'output',status:'completed'}});
    assert.equal(f.events.at(-1).entry.isError,true); assert.match(f.events.at(-1).entry.result,/Exit code: 1/);
    f.notify('item/completed',{item:{type:'fileChange',id:'file',changes:[{path:'a',diff:'+new'}],status:'completed'}});
    assert.match(f.events.at(-1).entry.result,/a\n\+new/);
    f.notify('item/completed',{item:{type:'mcpToolCall',id:'mcp',server:'s',tool:'t',status:'failed',error:{message:'denied'}}});
    assert.equal(f.events.at(-1).entry.isError,true);
});

test('approval id zero is preserved and only explicitly answered once', () => {
    const f=fixture(); f.connect(); f.start();
    f.c.receive({id:0,method:'item/commandExecution/requestApproval',params:{threadId:f.c.thread,turnId:f.c.turn,itemId:'cmd',command:'echo hello'}});
    assert.equal(f.events.at(-1).requests[0].id,0); assert.equal(f.wire.length,0);
    f.c.respond(0,{decision:'decline'});
    assert.deepEqual(f.wire,[{id:0,result:{decision:'decline'}}]);
    f.c.respond(0,{decision:'accept'}); assert.equal(f.wire.length,1);
});

test('concurrent requests survive independent responses and server resolution', () => {
    const f=fixture(); f.connect(); f.start();
    for (const id of ['a','b']) f.c.receive({id,method:'item/permissions/requestApproval',params:{threadId:f.c.thread,turnId:f.c.turn,permissions:{}}});
    f.c.respond('a',{permissions:{},scope:'turn'});
    assert.deepEqual(f.events.at(-1).requests.map(r=>r.id),['b']);
    f.notify('serverRequest/resolved',{requestId:'b'}); assert.deepEqual(f.events.at(-1).requests,[]);
});

test('unknown and foreign-thread requests receive errors without approval', () => {
    const f=fixture(); f.connect(); f.start();
    f.c.receive({id:'unknown',method:'new/method',params:{threadId:f.c.thread}});
    f.c.receive({id:'foreign',method:'item/fileChange/requestApproval',params:{threadId:'other'}});
    assert.equal(f.wire.length,2); assert.ok(f.wire.every(m=>m.error && !m.result));
});

test('cancels before initialization without ever starting a turn', () => {
    const f=fixture(); f.c.send('hello'); f.c.cancel(); f.connect();
    assert.equal(f.c.busy,false); assert.equal(f.wire.some(m=>m.method==='turn/start'),false);
});

test('cancels during thread/start without starting a turn', () => {
    const f=fixture(); f.connect(); f.c.send('hello');
    const thread=f.take('thread/start'); f.c.cancel();
    f.reply(thread,{thread:{id:'thread-1'},model:'configured'});
    assert.equal(f.c.busy,false); assert.equal(f.wire.some(m=>m.method==='turn/start'),false);
});

test('cancels during turn/start and waits for turn completion', () => {
    const f=fixture(); f.connect(); f.c.send('hello');
    f.reply(f.take('thread/start'),{thread:{id:'thread-1'},model:'configured'});
    const start=f.take('turn/start'); f.c.cancel();
    f.notify('turn/started',{turn:{id:'turn-1',status:'inProgress'}});
    const interrupt=f.take('turn/interrupt'); f.reply(start,{turn:{id:'turn-1'}});
    assert.equal(f.wire.some(m=>m.method==='turn/interrupt'),false);
    f.reply(interrupt,{}); assert.equal(f.c.busy,true);
    f.notify('turn/completed',{turn:{id:'turn-1',status:'interrupted'}}); assert.equal(f.c.busy,false);
});

test('New interrupts first, then drops the thread', () => {
    const f=fixture(); f.connect(); f.start(); f.c.reset(); assert.equal(f.c.thread,'thread-1');
    f.reply(f.take('turn/interrupt'),{});
    f.notify('turn/completed',{turn:{id:'turn-1',status:'interrupted'}});
    assert.equal(f.c.thread,''); assert.equal(f.events.at(-1).type,'reset');
    assert.equal(f.take('thread/unsubscribe').params.threadId,'thread-1');
});

test('crash preserves thread and configured default for resumption', () => {
    const f=fixture(); f.connect(); f.start('chosen'); f.c.disconnected('crashed');
    assert.equal(f.c.busy,false); assert.equal(f.c.thread,'thread-1');
    f.connect(); f.c.send('continue','');
    f.reply(f.take('thread/resume'),{thread:{id:'thread-1'},model:'chosen'});
    assert.equal(f.take('turn/start').params.model,'configured');
});

test('stale turns cannot append output to a later turn', () => {
    const f=fixture(); f.connect(); f.start();
    f.notify('turn/completed',{turn:{id:'turn-1',status:'completed'}});
    f.start('', 'turn-2'); const count=f.events.length;
    f.notify('item/agentMessage/delta',{turnId:'turn-1',itemId:'old',delta:'stale'});
    assert.equal(f.events.length,count);
});

test('late start reply cannot revive a completed turn', () => {
    const f=fixture(); f.connect(); f.c.send('hello');
    f.reply(f.take('thread/start'),{thread:{id:'thread-1'},model:'configured'});
    const start=f.take('turn/start');
    f.notify('turn/started',{turn:{id:'turn-1'}});
    f.notify('turn/completed',{turn:{id:'turn-1',status:'completed'}});
    f.reply(start,{turn:{id:'turn-1'}}); assert.equal(f.c.turn,''); assert.equal(f.c.busy,false);
});

test('request failure clears busy; recoverable stream error keeps waiting', () => {
    const f=fixture(); f.connect(); f.start();
    f.notify('error',{willRetry:true,error:{message:'retry'}}); assert.equal(f.c.busy,true);
    f.notify('turn/completed',{turn:{id:'turn-1',status:'completed'}});
    f.c.send('next'); const start=f.take('turn/start');
    f.c.receive({id:start.id,error:{message:'model unavailable'}});
    assert.equal(f.c.busy,false); assert.match(f.events.at(-1).error,/model unavailable/);
});

test('request and cancellation timeouts close the connection', () => {
    const f=fixture(); f.c.connected(); f.c.pending[f.wire[0].id].deadline=0; f.c.tick();
    assert.equal(f.events.at(-1).type,'fatal');
    const g=fixture(); g.connect(); g.start(); g.c.cancel(); g.c.cancelDeadline=1; g.c.tick();
    assert.equal(g.c.busy,false); assert.equal(g.events.at(-1).type,'fatal');
});

test('model pagination and late token usage are handled', () => {
    const f=fixture(); f.c.connected(); f.reply(f.take('initialize'),{}); f.take('initialized');
    f.reply(f.take('model/list'),{data:[{model:'a'}],nextCursor:'next'});
    const next=f.take('model/list'); assert.equal(next.params.cursor,'next');
    f.reply(next,{data:[{model:'b'}]}); assert.equal(f.events.at(-1).models.length,2);
    f.start(); f.notify('turn/completed',{turn:{id:'turn-1',status:'completed'}});
    f.notify('thread/tokenUsage/updated',{turnId:'turn-1',tokenUsage:{last:{totalTokens:23}}});
    assert.equal(f.events.at(-1).usage.totalTokens,23);
});

// Exercise actual QML presentation functions without a compositor.
function presentation() {
    const src=fs.readFileSync(path.join(root,'services/Ask.qml'),'utf8');
    const names=[...src.matchAll(/^    function (\w+)\(/gm)].map(m=>m[1]);
    const funcs=[...src.matchAll(/^    function \w+\([^]*?^    }/gm)].map(m=>m[0]).join('\n');
    const ask={transcript:[],latestTurnStart:0,quickAnswer:'',streamId:'',streamText:'',requests:[],requestDrafts:{},busy:false};
    const ctx=vm.createContext({ask,Session:{locked:false}});
    vm.runInContext(funcs,ctx);
    for(const n of names) if(ctx[n]) ask[n]=ctx[n];
    return ask;
}

test('Quick retains completed blocks on cancel and authoritative text does not duplicate deltas', () => {
    const a=presentation();
    a.handleEvent({type:'message',id:'one',text:'First block'});
    a.handleEvent({type:'delta',id:'two',text:'Partial second'});
    a.handleEvent({type:'done',status:'interrupted',durationMs:100});
    assert.match(a.quickAnswer,/First block\n\nPartial second/);
    a.handleEvent({type:'message',id:'two',text:'Authoritative second'});
    assert.equal(a.transcript.length,2);
    assert.equal(a.quickAnswer,'First block\n\nAuthoritative second\n\n');
});

test('interrupted tool cards finish and concurrent request drafts survive', () => {
    const a=presentation();
    a.handleEvent({type:'tool',entry:{kind:'tool',id:'cmd',result:'partial',done:false}});
    a.handleEvent({type:'done',status:'failed',durationMs:100});
    assert.equal(a.transcript[0].done,true); assert.equal(a.transcript[0].isError,true);
    a.saveRequestDraft('a','question','my answer');
    a.handleEvent({type:'requests',requests:[{id:'a'},{id:'b'}]});
    assert.equal(a.requestDrafts.a.question,'my answer');
    a.handleEvent({type:'requests',requests:[]}); assert.deepEqual(plain(a.requestDrafts),{});
});
