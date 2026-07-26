# serial.pas — IRQ + Ring Buffer Addition

Written 2026-07-26. For sysop/0.

## The diagram

```
Modem ←→ UART 16550 ←→ IRQ 4 ←→ ISR ←→ Ring Buffer
              ✅              ❌       ❌       ❌
          serial.pas                              
          has Port[]                              ↓
          register I/O                     SerRead (from ring)
                                                  ↓
                                          tork netmodem2irc
                                                  ↓
                                        TCP (sockets.pp) ←→ IRC
```

serial.pas v1.0 does polled I/O: `SerRead` checks LSR and reads RBR
in a loop. That works but loses bytes if the caller doesn't poll fast
enough — at 9600 baud a byte arrives every ~1ms, and if tork spends
2ms processing a TCP packet, the next UART byte overwrites the one in
RBR before `SerRead` gets back to it.

The fix is the standard one: an ISR fires on every received byte,
moves it to a ring buffer, and `SerRead` pulls from the ring instead
of from the hardware. Bytes are never lost because the ISR runs
between any two instructions.

## What to add

### 1. Ring buffer (per-port)

```pascal
const
  SER_RING_SIZE = 4096;   { match NM_UART16550's RING_SIZE }

type
  TSerRing = record
    Buf  : array[0..SER_RING_SIZE-1] of Byte;
    Head : Word;   { write position (ISR writes here) }
    Tail : Word;   { read position (SerRead reads here) }
    Count: Word;   { bytes in the ring }
  end;

var
  RxRing: array[0..3] of TSerRing;   { one per COM port }
```

Circular queue. ISR writes at Head, SerRead reads at Tail. `Count`
is the fill level — `SerDataAvailable` returns `Count > 0` instead
of polling LSR.

### 2. ISR (Interrupt Service Routine)

```pascal
{ COM1/COM3 share IRQ 4 (INT $0C). COM2/COM4 share IRQ 3 (INT $0B).
  The ISR must:
  1. Read IIR to confirm the interrupt source is this UART
  2. While IIR says "data ready":
     a. Read RBR → push byte into the ring
     b. Re-read IIR (16550 can have multiple pending interrupts)
  3. Send EOI to the 8259 PIC (Port[$20] := $20)
  4. IRET (handled by the 'interrupt' directive) }

procedure ComISR(
  Flags, CS, IP, AX, BX, CX, DX, SI, DI, DS, ES, BP: Word); interrupt;
var
  Base: Word;
  PortIdx: Integer;
  B: Byte;
begin
  { determine which port triggered — check both ports on this IRQ }
  for PortIdx := ... do begin   { 0,2 for IRQ4 or 1,3 for IRQ3 }
    Base := COM_BASE[PortIdx];
    while (Port[Base + UART_IIR] and $06) = $04 do begin
      { IIR bits [2:1] = 10 means "received data available" }
      B := Port[Base + UART_RBR];
      with RxRing[PortIdx] do begin
        if Count < SER_RING_SIZE then begin
          Buf[Head] := B;
          Head := (Head + 1) mod SER_RING_SIZE;
          Inc(Count);
        end;
        { else: ring full, byte dropped — count an overrun }
      end;
    end;
  end;
  { EOI to the 8259 PIC — must happen or no more interrupts fire }
  Port[$20] := $20;
end;
```

### 3. Install / remove the ISR

```pascal
var
  OldIRQ3, OldIRQ4: Pointer;   { saved vectors }

procedure SerInstallISR;
begin
  { save old vectors }
  GetIntVec($0B, OldIRQ3);   { IRQ 3 = INT $0B }
  GetIntVec($0C, OldIRQ4);   { IRQ 4 = INT $0C }
  { install ours }
  SetIntVec($0B, @ComISR);
  SetIntVec($0C, @ComISR);
  { unmask IRQ 3 and IRQ 4 in the 8259 PIC }
  Port[$21] := Port[$21] and not ($08 or $10);
  { enable UART receive interrupts (IER bit 0) }
  for each open port:
    Port[Base + UART_IER] := Port[Base + UART_IER] or $01;
end;

procedure SerRemoveISR;
begin
  { disable UART receive interrupts }
  for each open port:
    Port[Base + UART_IER] := Port[Base + UART_IER] and not $01;
  { restore old vectors }
  SetIntVec($0B, OldIRQ3);
  SetIntVec($0C, OldIRQ4);
  { re-mask IRQs if we were the only handler — or leave them
    for the old handler. Conservative: leave unmasked. }
end;
```

### 4. Change SerRead to read from the ring

```pascal
function SerRead(Handle: TSerialHandle; var Buffer; Count: LongInt): LongInt;
var P: PByte; I: LongInt;
begin
  Result := 0;
  P := @Buffer;
  { HAZARD: must disable interrupts while reading the ring, or the
    ISR could modify Head/Count between our reads of Tail and Count.
    On i8086/go32v2: asm cli / asm sti. Keep the critical section
    as short as possible — copy one byte, re-enable, loop. }
  with RxRing[Handle] do
    for I := 0 to Count-1 do begin
      asm cli end;
      if Count = 0 then begin asm sti end; Break; end;
      P^ := Buf[Tail];
      Tail := (Tail + 1) mod SER_RING_SIZE;
      Dec(Count);
      asm sti end;
      Inc(P); Inc(Result);
    end;
end;
```

### 5. Change SerDataAvailable

```pascal
function SerDataAvailable(Handle: TSerialHandle): Boolean;
begin
  Result := RxRing[Handle].Count > 0;
end;
```

## What NOT to change

`SerWrite` stays polled. Transmit interrupts (THRE) are a luxury —
the bottleneck is always receive, because missed TX bytes mean "sent
slower" while missed RX bytes mean "data lost." TX can go IRQ-driven
later if throughput demands it.

`SerOpen` / `SerClose` need to call `SerInstallISR` / `SerRemoveISR`
at the right points. `SerClose` must also drain the ring.

## Where it goes

Two options:

1. **In serial.pas itself** — keep it one file, `{$IFDEF IRQ_SERIAL}`
   guarded so the polled version still compiles for testing
2. **A separate serial_irq.pas** that uses serial.pas and adds the
   ring + ISR layer on top

Option 1 is simpler. The polled path is useful for debugging (no ISR
means no reentrancy hazards), so keeping both behind a define is worth
it.

## The CLI/STI hazard

The ring is shared between the ISR (interrupt context) and `SerRead`
(normal context). Without `cli`/`sti` around the ring access in
`SerRead`, the ISR could fire between reading `Tail` and reading
`Count`, corrupting the state.

On go32v2 this is `asm cli end` / `asm sti end`.
On i8086 the same instructions work — they're native 8086.

Keep the critical section to ONE byte per iteration. Do not hold
interrupts disabled across the entire buffer copy — that would delay
all other interrupts (timer, keyboard) for the duration.

## IRQ sharing (COM1+COM3, COM2+COM4)

COM1 and COM3 share IRQ 4. COM2 and COM4 share IRQ 3. The ISR must
check ALL ports on its IRQ — read each port's IIR, service whichever
has data. This is why the ISR loops over port indices rather than
hardcoding one port.

The original PC/AT had edge-triggered IRQs, which means a shared IRQ
can miss the second port's interrupt if both fire simultaneously. The
16550A's FIFO mitigates this (fewer interrupts per byte), and
`SerSetFIFO(H, True, 14)` is already in the API.

## See also

- `engine/NM_UART16550.pas` — the emulated version has the same ring
  structure (`RING_SIZE = 4096`, `Head`/`Tail`/`Count`)
- `engine/NM_Int14ISR.pas` — the INT 14h vector hook follows the same
  `GetIntVec`/`SetIntVec` + `interrupt` pattern
- `docs/fpc264irc_sockets_lifecycle.md` — the Init/Done pattern
  applies here too: `SerInstallISR` is Init, `SerRemoveISR` is Done,
  the program owns the lifecycle
