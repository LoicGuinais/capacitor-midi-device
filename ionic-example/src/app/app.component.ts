import {ChangeDetectorRef, Component, OnInit} from '@angular/core';
import {DeviceOptions, CapacitorMIDIDevice, MidiMessage} from 'capacitor-midi-device';
@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
})
export class AppComponent implements OnInit{
  devices: string[] = [];
  messages: MidiMessage[] = [];
  opened = false;

  constructor(private cd: ChangeDetectorRef) {
  }

  async ngOnInit(): Promise<void> {
    this.devices = (await CapacitorMIDIDevice.listMIDIDevices()).value;

    CapacitorMIDIDevice.addListener('MIDI_MSG_EVENT', (message: MidiMessage) => {
      this.messages.push(message);
      this.cd.detectChanges();
    });

    await CapacitorMIDIDevice.initConnectionListener();

    CapacitorMIDIDevice.addListener('MIDI_CON_EVENT', (devices: { value: string[] }) => {
      this.devices = devices.value;
      this.cd.detectChanges();
    });
  }

  updateDevices(): void {
    CapacitorMIDIDevice.listMIDIDevices()
      .then((devices: { value: string[] }) => {
        this.devices = devices.value;
        this.cd.detectChanges();
      });
  }

  openDevice(deviceNumber: number): void {
    const deviceOptions: DeviceOptions = {
      deviceNumber
    };
    CapacitorMIDIDevice.openDevice(deviceOptions).then(r => {
      this.clearMessages();
    });
  }

  clearMessages(): void {
    this.messages = [];
  }

  msgToString(msg: MidiMessage): string {
    return JSON.stringify(msg);
  }
}
