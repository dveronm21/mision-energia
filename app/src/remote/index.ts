/** Modo TV: el tele es el host y hasta 2 tablets lo controlan por Wi-Fi. */
export * from './protocol';
export { RemoteHost, defaultContext, CTX_MIN_INTERVAL_MS, type RemotePlayer, type RemoteHostOptions, type LeaveReason, type DropReason } from './RemoteHost';
export { RemoteInputSource, shapeStick, DEFAULT_STICK, type StickTuning } from './RemoteInputSource';
export { LobbyView, type LobbyViewOptions } from './LobbyView';
export { FakeBridge, FakeClient } from './FakeBridge';
