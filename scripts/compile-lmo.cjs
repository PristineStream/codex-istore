#!/usr/bin/env node
'use strict';
// SPDX-License-Identifier: Apache-2.0
// LuCI po2lmo uses SuperFastHash, padded UTF-8 values, and a big-endian index.
// Sources: openwrt/luci modules/luci-base/src/{po2lmo.c,lib/lmo.c,lib/lmo.h}.
// LuCI LMO copyright (C) 2009-2010 Jo-Philipp Wich.
// SuperFastHash copyright (C) 2004-2008 Paul Hsieh.
// Deliberately accepts only single-line msgid/msgstr entries and a multiline
// metadata header. Context, plurals, fuzzy entries, and other PO forms fail.
const fs = require('fs');

function fail(message) { throw new Error(message); }
function hash(b) {
  let h = b.length >>> 0, p = 0, n = b.length >>> 2, t;
  const u16 = i => b[i] | (b[i + 1] << 8);
  const signed = x => x < 128 ? x : x - 256;
  while (n--) {
    h = (h + u16(p)) >>> 0;
    t = ((u16(p + 2) << 11) ^ h) >>> 0;
    h = ((h << 16) ^ t) >>> 0;
    p += 4;
    h = (h + (h >>> 11)) >>> 0;
  }
  switch (b.length & 3) {
    case 3:
      h = (h + u16(p)) >>> 0; h = (h ^ (h << 16)) >>> 0;
      h = (h ^ (signed(b[p + 2]) << 18)) >>> 0; h = (h + (h >>> 11)) >>> 0; break;
    case 2:
      h = (h + u16(p)) >>> 0; h = (h ^ (h << 11)) >>> 0;
      h = (h + (h >>> 17)) >>> 0; break;
    case 1:
      h = (h + signed(b[p])) >>> 0; h = (h ^ (h << 10)) >>> 0;
      h = (h + (h >>> 1)) >>> 0;
  }
  h = (h ^ (h << 3)) >>> 0; h = (h + (h >>> 5)) >>> 0;
  h = (h ^ (h << 4)) >>> 0; h = (h + (h >>> 17)) >>> 0;
  h = (h ^ (h << 25)) >>> 0; h = (h + (h >>> 6)) >>> 0;
  return h;
}
function parseQuoted(s, line, header) {
  // po2lmo unescapes only quotes and backslashes for ordinary messages.
  if (!header && /\\(?!["\\])/.test(s)) fail(`line ${line}: unsupported escape`);
  try { return JSON.parse(s); } catch { fail(`line ${line}: invalid quoted string`); }
}
function compile(source) {
  const entries = [], seen = new Set(), keys = new Set();
  let id = null, value = null, state = 'start', headerSeen = false;
  function finish(line) {
    if (id === null) return;
    if (value === null) fail(`line ${line}: missing msgstr`);
    if (id === '') {
      if (headerSeen) fail(`line ${line}: duplicate header`);
      headerSeen = true;
    } else {
      if (id !== id.replace(/[\t\n\v\f\r ]+/g, ' ').replace(/^ | $/g, ''))
        fail(`line ${line}: msgid whitespace is not canonical`);
      if (id.includes('\0') || value.includes('\0')) fail(`line ${line}: NUL is unsupported`);
      if (Buffer.byteLength(id) >= 4096) fail(`line ${line}: msgid too long`);
      if (seen.has(id)) fail(`line ${line}: duplicate msgid`);
      seen.add(id);
      if (value) {
        const key = hash(Buffer.from(id)), val = Buffer.from(value);
        if (key !== hash(val)) {
          if (key === 0) fail(`line ${line}: reserved message hash`);
          if (keys.has(key)) fail(`line ${line}: hash collision`);
          keys.add(key); entries.push({ key, val });
        }
      }
    }
    id = null; value = null; state = 'start';
  }
  const lines = source.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i], number = i + 1;
    if (!line.trim()) { finish(number); continue; }
    if (line.startsWith('#')) {
      if (/^#,.*\bfuzzy\b/.test(line)) fail(`line ${number}: fuzzy entries unsupported`);
      if (id !== null) fail(`line ${number}: comments within an entry unsupported`);
      continue;
    }
    let m;
    if ((m = /^msgid ("(?:[^"\\]|\\.)*")$/.exec(line))) {
      if (id !== null) fail(`line ${number}: missing entry separator`);
      id = parseQuoted(m[1], number, false); state = 'id';
    } else if ((m = /^msgstr ("(?:[^"\\]|\\.)*")$/.exec(line))) {
      if (state !== 'id') fail(`line ${number}: unexpected msgstr`);
      value = parseQuoted(m[1], number, id === ''); state = 'value';
    } else if ((m = /^("(?:[^"\\]|\\.)*")$/.exec(line))) {
      if (id !== '' || state !== 'value') fail(`line ${number}: continuation supported only in metadata header`);
      value += parseQuoted(m[1], number, true);
    } else fail(`line ${number}: unsupported PO syntax`);
  }
  finish(lines.length);
  if (!entries.length) fail('no translated entries');
  let offset = 0;
  const values = [], index = [];
  for (const {key, val} of entries) {
    const padded = Buffer.alloc((val.length + 3) & ~3);
    val.copy(padded); values.push(padded);
    index.push({key, offset, length: val.length}); offset += padded.length;
  }
  index.sort((a, b) => a.key - b.key);
  const table = Buffer.alloc(index.length * 16 + 4);
  index.forEach((e, i) => {
    const n = i * 16;
    table.writeUInt32BE(e.key, n); table.writeUInt32BE(1, n + 4);
    table.writeUInt32BE(e.offset, n + 8); table.writeUInt32BE(e.length, n + 12);
  });
  table.writeUInt32BE(offset, index.length * 16);
  return Buffer.concat([...values, table]);
}
try {
  if (process.argv.length !== 4) fail('usage: node compile-lmo.cjs input.po output.lmo');
  const source = new TextDecoder('utf-8', {fatal: true}).decode(fs.readFileSync(process.argv[2]));
  const result = compile(source);
  fs.writeFileSync(process.argv[3], result);
} catch (e) { console.error(`compile-lmo: ${e.message}`); process.exitCode = 1; }
