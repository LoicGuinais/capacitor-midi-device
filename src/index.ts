import { registerPlugin } from '@capacitor/core';

import type { CapacitorMIDIDevicePlugin } from './definitions';

const CapacitorMIDIDevice = registerPlugin<CapacitorMIDIDevicePlugin>(
  'CapacitorMIDIDevice',
  {
    web: () => import('./web').then(m => new m.CapacitorMIDIDeviceWeb()),
  },
);

export * from './definitions';
export { CapacitorMIDIDevice };
