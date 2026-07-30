export type TelemetryScalar = boolean | number | string;

export interface TelemetryEvent {
  name: string;
  properties: Readonly<Record<string, TelemetryScalar>>;
}

export interface TelemetryError {
  category: string;
  context: Readonly<Record<string, TelemetryScalar>>;
  source: string;
}

export interface TelemetrySink {
  captureError(error: TelemetryError): void;
  track(event: TelemetryEvent): void;
}

export class Telemetry {
  readonly #sink: TelemetrySink;

  constructor(sink: TelemetrySink) {
    this.#sink = sink;
  }

  captureError(error: TelemetryError): void {
    this.#sink.captureError(error);
  }

  track(event: TelemetryEvent): void {
    this.#sink.track(event);
  }
}
