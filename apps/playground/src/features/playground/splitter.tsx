import {
  useEffect,
  type KeyboardEvent,
  type PointerEvent,
  type RefObject,
} from 'react';

type SplitterOrientation = 'horizontal' | 'vertical';

interface SplitterProps {
  ariaControls: string;
  ariaLabel: string;
  containerRef: RefObject<HTMLElement | null>;
  minPrimaryPx: number;
  minSecondaryPx: number;
  onChange(value: number): void;
  onReset(): void;
  orientation: SplitterOrientation;
  value: number;
}

const SPLITTER_SIZE_PX = 7;

function getBounds(
  container: HTMLElement | null,
  orientation: SplitterOrientation,
  minPrimaryPx: number,
  minSecondaryPx: number,
) {
  const size =
    orientation === 'vertical'
      ? container?.clientWidth ?? 0
      : container?.clientHeight ?? 0;

  if (size <= minPrimaryPx + minSecondaryPx + SPLITTER_SIZE_PX) {
    return { min: 0, max: 100 };
  }

  return {
    min: (minPrimaryPx / size) * 100,
    max: ((size - minSecondaryPx - SPLITTER_SIZE_PX) / size) * 100,
  };
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export function Splitter({
  ariaControls,
  ariaLabel,
  containerRef,
  minPrimaryPx,
  minSecondaryPx,
  onChange,
  onReset,
  orientation,
  value,
}: SplitterProps) {
  const bounds = getBounds(
    containerRef.current,
    orientation,
    minPrimaryPx,
    minSecondaryPx,
  );

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const observer = new ResizeObserver(() => {
      const nextBounds = getBounds(
        container,
        orientation,
        minPrimaryPx,
        minSecondaryPx,
      );
      const nextValue = clamp(value, nextBounds.min, nextBounds.max);
      if (Math.abs(nextValue - value) > 0.01) onChange(nextValue);
    });

    observer.observe(container);
    return () => observer.disconnect();
  }, [containerRef, minPrimaryPx, minSecondaryPx, onChange, orientation, value]);

  const updateFromPointer = (event: PointerEvent<HTMLDivElement>) => {
    const container = containerRef.current;
    if (!container) return;

    const rect = container.getBoundingClientRect();
    const size = orientation === 'vertical' ? rect.width : rect.height;
    if (size <= 0) return;

    const position =
      orientation === 'vertical'
        ? event.clientX - rect.left
        : event.clientY - rect.top;
    const nextBounds = getBounds(
      container,
      orientation,
      minPrimaryPx,
      minSecondaryPx,
    );
    onChange(clamp((position / size) * 100, nextBounds.min, nextBounds.max));
  };

  const handlePointerDown = (event: PointerEvent<HTMLDivElement>) => {
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    updateFromPointer(event);
  };

  const handlePointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (!event.currentTarget.hasPointerCapture(event.pointerId)) return;
    updateFromPointer(event);
  };

  const handlePointerEnd = (event: PointerEvent<HTMLDivElement>) => {
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = event.shiftKey ? 8 : 2;
    let nextValue: number | undefined;

    if (event.key === 'Home') nextValue = bounds.min;
    if (event.key === 'End') nextValue = bounds.max;
    if (event.key === 'Enter') {
      event.preventDefault();
      onReset();
      return;
    }

    if (orientation === 'vertical') {
      if (event.key === 'ArrowLeft') nextValue = value - step;
      if (event.key === 'ArrowRight') nextValue = value + step;
    } else {
      if (event.key === 'ArrowUp') nextValue = value - step;
      if (event.key === 'ArrowDown') nextValue = value + step;
    }

    if (nextValue === undefined) return;
    event.preventDefault();
    onChange(clamp(nextValue, bounds.min, bounds.max));
  };

  return (
    <div
      aria-controls={ariaControls}
      aria-label={ariaLabel}
      aria-orientation={orientation}
      aria-valuemax={Math.round(bounds.max)}
      aria-valuemin={Math.round(bounds.min)}
      aria-valuenow={Math.round(value)}
      className={`pane-splitter pane-splitter-${orientation}`}
      onDoubleClick={onReset}
      onKeyDown={handleKeyDown}
      onPointerCancel={handlePointerEnd}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerEnd}
      role="separator"
      tabIndex={0}
    />
  );
}
