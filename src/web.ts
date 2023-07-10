import { WebPlugin } from '@capacitor/core';

import type { CapacitorMIDIDevicePlugin } from './definitions';

export class CapacitorMIDIDeviceWeb
  extends WebPlugin
  implements CapacitorMIDIDevicePlugin
{
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
