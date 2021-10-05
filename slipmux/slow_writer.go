// This is a hacky workaround for the fact that the HiFive1 FTDI chip
// doesn't do hardware flow control and the UART0 interrupt handler
// takes an eternity to complete since it does CoAP message handling.
package main

import (
	"io"
	"time"
)

const (
	pause = 1 * time.Second
	fifoDepth = 8
)

type SlowWriter struct {
	w io.Writer
}

func NewSlowWriter(w io.Writer) SlowWriter {
	return SlowWriter{w: w}
}

func (w SlowWriter) Write(p []byte) (int, error) {
	var n int
	for i, c := range p {
		if i != 0 && i%fifoDepth == 0 {
			time.Sleep(pause)
		}

		written, err := w.w.Write([]byte{c})
		if err != nil {
			return n, err
		}

		n += written
	}

	return n, nil
}
