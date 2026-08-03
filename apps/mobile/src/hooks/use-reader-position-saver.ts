import { useCallback, useEffect, useRef } from 'react';

import {
  createReaderPositionWriteQueue,
  type ReaderPositionWriteQueue,
} from '@novella/reader-engine';

export function useReaderPositionSaver<Input, Checkpoint = Input>(
  persist: (position: Checkpoint) => void | Promise<void>,
  delayMs = 450,
  stage: (position: Input) => Checkpoint = ((position: Input) => position as unknown as Checkpoint),
): {
  commit: (position: Input) => Promise<void>;
  flush: () => Promise<void>;
  schedule: (position: Input) => void;
} {
  const persistRef = useRef(persist);
  const stageRef = useRef(stage);
  const queueRef = useRef<ReaderPositionWriteQueue<Checkpoint> | null>(null);
  persistRef.current = persist;
  stageRef.current = stage;

  if (queueRef.current === null) {
    queueRef.current = createReaderPositionWriteQueue(
      (position) => persistRef.current(position),
      { delayMs },
    );
  }

  const commit = useCallback(
    (position: Input) => queueRef.current!.commit(stageRef.current(position)),
    [],
  );
  const flush = useCallback(() => queueRef.current!.flush(), []);
  const schedule = useCallback(
    (position: Input) => queueRef.current!.schedule(stageRef.current(position)),
    [],
  );

  useEffect(() => () => {
    void queueRef.current?.dispose();
  }, []);

  return { commit, flush, schedule };
}
