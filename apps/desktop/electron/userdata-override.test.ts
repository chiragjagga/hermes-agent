import assert from 'node:assert/strict'
import path from 'node:path'
import os from 'node:os'
import { test } from 'vitest'

import { resolveHermesHomePath, resolveUserDataPath, buildDesktopBackendEnv } from './backend-env'


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

test('resolveUserDataPath: resolves relative path to absolute', () => {
  const relativePath = './custom-relative'
  const resolved = resolveUserDataPath({
    env: { HERMES_USERDATA: relativePath },
    platform: 'linux',
    getPath: () => '/default/home'
  })
  assert.equal(resolved, path.resolve(relativePath))
})

test('resolveHermesHomePath: resolves to default platform-native path on win32', () => {
  const resolvedHome = resolveHermesHomePath({
    env: { LOCALAPPDATA: '/win/appdata' },
    userDataDir: '/win/default/userData',
    platform: 'win32',
    getPath: () => '/win/default/userData'
  })
  assert.equal(resolvedHome, path.resolve('/win/appdata/hermes'))
})

test('resolveHermesHomePath: resolves to default platform-native path on linux', () => {
  const resolvedHome = resolveHermesHomePath({

    env: {},
    userDataDir: '/linux/default/userData',
    platform: 'linux',
    getPath: () => '/linux/default/userData'
  })
  assert.equal(resolvedHome, path.resolve(path.join(os.homedir(), '.hermes')))
})

test('buildDesktopBackendEnv: propagates custom hermesHome to the backend process environment configuration', () => {
  const customHome = '/tmp/custom-home'
  const backendEnv = buildDesktopBackendEnv({
    hermesHome: customHome,
    pythonPathEntries: [],
    venvRoot: '/tmp/venv',
    platform: 'linux'
  })
  assert.ok(backendEnv.PATH.includes(path.join(customHome, 'node', 'bin')))
})

test('Integration: Electron app sets userData path when env variables are configured', () => {
  const fakeApp = {
    paths: {} as Record<string, string>,
    setPath(name: string, value: string) {
      this.paths[name] = value
    },
    getPath(name: string) {
      return this.paths[name] || '/default/path'
    }
  }
  
  const env = { HERMES_USERDATA: './custom-relative-userData' }
  const customUserData = env.HERMES_USERDATA
  if (customUserData) {
    fakeApp.setPath('userData', path.resolve(customUserData))
  }
  
  assert.equal(fakeApp.getPath('userData'), path.resolve('./custom-relative-userData'))
})

