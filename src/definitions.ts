export interface CapacitorMIDIDevicePlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
