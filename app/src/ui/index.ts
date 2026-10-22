/** API pública de la capa de UI. */
export { UiRoot, type UiRootOptions } from './UiRoot';
export { ScreenManager } from './ScreenManager';
export { UI_CSS } from './styles';
export * from './types';
export { icon, resolveIcon, type IconName } from './icons';

export { Hud, type HudCallbacks } from './hud/Hud';
export { Joystick, type JoystickVector } from './hud/Joystick';
export { ActionButtons, type ActionButtonsCallbacks } from './hud/ActionButtons';
export { MissionPanel } from './hud/MissionPanel';
export { StatsPanel } from './hud/StatsPanel';
export { AlertBanner } from './hud/AlertBanner';
export { Toast } from './hud/Toast';
export { WorldPrompt } from './hud/WorldPrompt';
export { MeterView } from './hud/MeterView';
export { InspectCard } from './hud/InspectCard';
export { LoadSheddingPanel } from './hud/LoadSheddingPanel';
export { WalletChip } from './hud/WalletChip';
export { BoosterBar } from './hud/BoosterBar';

export { SplashScreen } from './screens/SplashScreen';
export { MainMenu, type MainMenuDeps } from './screens/MainMenu';
export { LevelMapScreen, type LevelMapDeps } from './screens/LevelMapScreen';
export { WorkshopScreen, WorkshopScreen as BriefingScreen, type WorkshopDeps } from './screens/WorkshopScreen';
export { ShopScreen, type ShopDeps, type ShopTab } from './screens/ShopScreen';
export { ParentalGateModal } from './screens/ParentalGateModal';
export { WardrobeScreen, cosmeticColor, cosmeticColorHex, cosmeticSlot, DEFAULT_COLORS, type WardrobeDeps, type CosmeticSlot } from './screens/WardrobeScreen';
export { ResultScreen, type ResultDeps } from './screens/ResultScreen';
export { PauseMenu, type PauseDeps } from './screens/PauseMenu';
export { SettingsScreen, type SettingsDeps } from './screens/SettingsScreen';
