# capacitor-midi-device

connect midi devices to your app

## Install

```bash
npm install @midiative/capacitor-midi-device
npx cap sync
```

## API

<docgen-index>

* [`listMIDIDevices()`](#listmididevices)
* [`openDevice(...)`](#opendevice)
* [`initConnectionListener()`](#initconnectionlistener)
* [`addListener('MIDI_MSG_EVENT', ...)`](#addlistenermidi_msg_event)
* [`addListener('MIDI_CON_EVENT', ...)`](#addlistenermidi_con_event)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### listMIDIDevices()

```typescript
listMIDIDevices() => Promise<{ value: string[]; }>
```

**Returns:** <code>Promise&lt;{ value: string[]; }&gt;</code>

--------------------


### openDevice(...)

```typescript
openDevice(options: DeviceOptions) => Promise<void>
```

| Param         | Type                                                    |
| ------------- | ------------------------------------------------------- |
| **`options`** | <code><a href="#deviceoptions">DeviceOptions</a></code> |

--------------------


### initConnectionListener()

```typescript
initConnectionListener() => Promise<void>
```

--------------------


### addListener('MIDI_MSG_EVENT', ...)

```typescript
addListener(eventName: 'MIDI_MSG_EVENT', listenerFunc: (message: MidiMessage) => void) => Promise<PluginListenerHandle> & PluginListenerHandle
```

| Param              | Type                                                                      |
| ------------------ | ------------------------------------------------------------------------- |
| **`eventName`**    | <code>'MIDI_MSG_EVENT'</code>                                             |
| **`listenerFunc`** | <code>(message: <a href="#midimessage">MidiMessage</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt; & <a href="#pluginlistenerhandle">PluginListenerHandle</a></code>

--------------------


### addListener('MIDI_CON_EVENT', ...)

```typescript
addListener(eventName: 'MIDI_CON_EVENT', listenerFunc: (devices: { value: string[]; }) => void) => Promise<PluginListenerHandle> & PluginListenerHandle
```

| Param              | Type                                                    |
| ------------------ | ------------------------------------------------------- |
| **`eventName`**    | <code>'MIDI_CON_EVENT'</code>                           |
| **`listenerFunc`** | <code>(devices: { value: string[]; }) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt; & <a href="#pluginlistenerhandle">PluginListenerHandle</a></code>

--------------------


### Interfaces


#### DeviceOptions

| Prop               | Type                |
| ------------------ | ------------------- |
| **`deviceNumber`** | <code>number</code> |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### MidiMessage

| Prop           | Type                |
| -------------- | ------------------- |
| **`type`**     | <code>string</code> |
| **`note`**     | <code>number</code> |
| **`velocity`** | <code>number</code> |

</docgen-api>
