import assert from 'node:assert/strict'
import path from 'node:path'
import { test } from 'vitest'

import { resolveHermesHomePath, resolveUserDataPath } from './backend-env'

test('resolveUserDataPath: returns process.env.HERMES_USERDATA if configured', () => {
  const customUserData = '/tmp/custom-userdata-dir'
  const resolved = resolveUserDataPath({
    env: { HERMES_USERDATA: customUserData },
    platform: 'linux',
    getPath: () => '/default/home'
  })
  assert.equal(resolved, path.resolve(customUserData))
})

test('resolveUserDataPath: returns process.env.HERMES_DESKTOP_USER_DATA_DIR if HERMES_USERDATA is unset', () => {
  const customUserData = '/tmp/custom-desktop-dir'
  const resolved = resolveUserDataPath({
    env: { HERMES_DESKTOP_USER_DATA_DIR: customUserData },
    platform: 'linux',
    getPath: () => '/default/home'
  })
  assert.equal(resolved, path.resolve(customUserData))
})

test('resolveUserDataPath: prefers HERMES_USERDATA over HERMES_DESKTOP_USER_DATA_DIR', () => {
  const customUserData = '/tmp/custom-userdata'
  const customDesktop = '/tmp/custom-desktop'
  const resolved = resolveUserDataPath({
    env: {
      HERMES_USERDATA: customUserData,
      HERMES_DESKTOP_USER_DATA_DIR: customDesktop
    },
    platform: 'linux',
    getPath: () => '/default/home'
  })
  assert.equal(resolved, path.resolve(customUserData))
})

test('resolveHermesHomePath: resolves to customUserData/hermes-home if userData is overridden', () => {
  const customUserData = '/tmp/custom-userdata'
  const resolvedHome = resolveHermesHomePath({
    env: {},
    userDataDir: customUserData,
    platform: 'linux',
    getPath: () => '/default/home'
  })
  assert.equal(resolvedHome, path.join(path.resolve(customUserData), 'hermes-home'))
})

test('resolveHermesHomePath: honors process.env.HERMES_HOME first even if userData is overridden', () => {
  const customUserData = '/tmp/custom-userdata'
  const explicitHome = '/explicit/hermes-home'
  const resolvedHome = resolveHermesHomePath({
    env: { HERMES_HOME: explicitHome },
    userDataDir: customUserData,
    platform: 'linux',
    getPath: () => '/default/home'
  })
  assert.equal(resolvedHome, path.resolve(explicitHome))
})
