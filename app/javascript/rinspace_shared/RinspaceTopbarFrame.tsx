// RINSPACE_SHARED_SOURCE: edit only in rinspace/ui, then run the one-way sync.
import { useEffect, useRef } from "react";
import type { MouseEventHandler, ReactNode, SyntheticEvent } from "react";
import { createPortal } from "react-dom";
import { motion, useReducedMotion } from "motion/react";

export interface RinspaceTopbarFrameProps {
  sessionState: "anonymous" | "restoring" | "authenticated";
  logoSrc: string;
  brandName: string;
  flipHref: string;
  homeHref: string;
  flipLabel: string;
  homeLabel: string;
  children: ReactNode;
  onFlipNavigate?: MouseEventHandler<HTMLAnchorElement>;
  onHomeNavigate?: MouseEventHandler<HTMLAnchorElement>;
}

export interface RinspaceTopbarControlsProps {
  search: ReactNode;
  navigationLabel: string;
  children: ReactNode;
}

/**
 * The single visual frame used by both Rinspace runtimes.
 *
 * Runtime adapters own data and navigation. This component owns the header DOM,
 * brand controls and their motion policy, so the inner world cannot silently
 * substitute a second logo, animated wordmark or different shell structure.
 */
export function RinspaceTopbarFrame({
  sessionState,
  logoSrc,
  brandName,
  flipHref,
  homeHref,
  flipLabel,
  homeLabel,
  children,
  onFlipNavigate,
  onHomeNavigate,
}: RinspaceTopbarFrameProps) {
  const reducedMotion = useReducedMotion();

  return (
    <header
      className="topbar rin-topbar-shell"
      data-session-state={sessionState}
    >
      <span className="brand">
        <motion.a
          className="brand-mark"
          href={flipHref}
          aria-label={flipLabel}
          onClick={onFlipNavigate}
          whileHover={reducedMotion ? undefined : { rotateY: 360 }}
          transition={{ type: "spring", stiffness: 260, damping: 20 }}
          style={{ transformPerspective: 600 }}
        >
          <img
            src={logoSrc}
            alt=""
            aria-hidden="true"
            draggable={false}
            width={128}
            height={128}
            decoding="sync"
            fetchPriority="high"
          />
        </motion.a>
        <a
          className="brand-word"
          href={homeHref}
          aria-label={homeLabel}
          onClick={onHomeNavigate}
        >
          <span className="brand-word-text">{brandName}</span>
        </a>
      </span>
      {children}
    </header>
  );
}

/**
 * Shared topbar slot order. The outer and inner adapters provide runtime
 * controls, but cannot change the search/navigation structure or button row.
 */
export function RinspaceTopbarControls({
  search,
  navigationLabel,
  children,
}: RinspaceTopbarControlsProps) {
  return (
    <>
      {search}
      <nav className="account-nav" aria-label={navigationLabel}>
        {children}
      </nav>
    </>
  );
}

export interface RinspacePhoneAuthDialogProps {
  open: boolean;
  busy: boolean;
  phone: string;
  code: string;
  challenge: boolean;
  error: string;
  status: string;
  labels: {
    title: string;
    close: string;
    phone: string;
    phonePlaceholder: string;
    code: string;
    codePlaceholder: string;
    changePhone: string;
    processing: string;
    complete: string;
    sendCode: string;
  };
  onClose: () => void;
  onPhoneChange: (value: string) => void;
  onCodeChange: (value: string) => void;
  onChangePhone: () => void;
  onSubmit: (event: SyntheticEvent<HTMLFormElement>) => void;
}

export function RinspacePhoneAuthDialog({
  open,
  busy,
  phone,
  code,
  challenge,
  error,
  status,
  labels,
  onClose,
  onPhoneChange,
  onCodeChange,
  onChangePhone,
  onSubmit,
}: RinspacePhoneAuthDialogProps) {
  const reducedMotion = useReducedMotion();
  const dialog = useRef<HTMLElement>(null);
  const phoneInput = useRef<HTMLInputElement>(null);
  const busyRef = useRef(busy);

  useEffect(() => {
    busyRef.current = busy;
  }, [busy]);

  useEffect(() => {
    if (!open) return undefined;
    const active = document.activeElement as HTMLElement | null;
    const focusFrame = window.requestAnimationFrame(() =>
      phoneInput.current?.focus(),
    );
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !busyRef.current) {
        onClose();
        return;
      }
      if (event.key !== "Tab") return;
      const focusable = Array.from(
        dialog.current?.querySelectorAll<HTMLElement>(
          'button:not(:disabled), input:not(:disabled), [href], [tabindex]:not([tabindex="-1"])',
        ) ?? [],
      );
      const first = focusable[0];
      const last = focusable.at(-1);
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first?.focus();
      }
    };
    document.addEventListener("keydown", onKeyDown);
    return () => {
      window.cancelAnimationFrame(focusFrame);
      document.removeEventListener("keydown", onKeyDown);
      active?.focus();
    };
  }, [onClose, open]);

  if (!open) return null;

  return createPortal(
    <>
      <motion.div
        className="rin-ui-overlay rin-auth-overlay"
        data-state="open"
        initial={reducedMotion ? false : { opacity: 0 }}
        animate={{ opacity: 1 }}
        onMouseDown={(event) => {
          if (event.target === event.currentTarget && !busy) onClose();
        }}
      />
      <motion.section
        ref={dialog}
        className="auth-dialog rin-auth-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="rinspace-auth-dialog-title"
        initial={reducedMotion ? false : { opacity: 0, y: 10, scale: 0.985 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: reducedMotion ? 0 : 0.18 }}
      >
        <div className="auth-dialog-head rin-auth-dialog__head">
          <h2 className="auth-dialog-title" id="rinspace-auth-dialog-title">
            {labels.title}
          </h2>
          <motion.button
            type="button"
            aria-label={labels.close}
            disabled={busy}
            onClick={onClose}
            whileHover={reducedMotion ? undefined : { y: -1 }}
            whileTap={reducedMotion ? undefined : { scale: 0.975 }}
          >
            <svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true">
              <path
                fill="currentColor"
                d="M2.15 2.85a.5.5 0 0 1 .7-.7L8 7.29l5.15-5.14a.5.5 0 0 1 .7.7L8.71 8l5.14 5.15a.5.5 0 0 1-.7.7L8 8.71l-5.15 5.14a.5.5 0 0 1-.7-.7L7.29 8z"
              />
            </svg>
          </motion.button>
        </div>
        <form
          className="auth-dialog-form rin-auth-dialog__form"
          onSubmit={onSubmit}
        >
          <label>
            <span>{labels.phone}</span>
            <input
              ref={phoneInput}
              type="tel"
              inputMode="tel"
              autoComplete="tel"
              value={phone}
              disabled={challenge || busy}
              placeholder={labels.phonePlaceholder}
              onChange={(event) => {
                onPhoneChange(event.currentTarget.value);
              }}
            />
          </label>
          {challenge ? (
            <label>
              <span>{labels.code}</span>
              <input
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                value={code}
                disabled={busy}
                placeholder={labels.codePlaceholder}
                onChange={(event) => {
                  onCodeChange(event.currentTarget.value);
                }}
              />
            </label>
          ) : null}
          {error ? (
            <p
              className="auth-dialog-error rin-auth-dialog__error"
              role="alert"
            >
              {error}
            </p>
          ) : null}
          {status ? (
            <p
              className="auth-dialog-status rin-auth-dialog__status"
              role="status"
            >
              {status}
            </p>
          ) : null}
          <div className="auth-dialog-actions rin-auth-dialog__actions">
            {challenge ? (
              <motion.button
                type="button"
                className="auth-dialog-link rin-auth-dialog__link"
                disabled={busy}
                onClick={onChangePhone}
              >
                {labels.changePhone}
              </motion.button>
            ) : null}
            <motion.button type="submit" disabled={busy}>
              {busy
                ? labels.processing
                : challenge
                  ? labels.complete
                  : labels.sendCode}
            </motion.button>
          </div>
        </form>
      </motion.section>
    </>,
    document.body,
  );
}
