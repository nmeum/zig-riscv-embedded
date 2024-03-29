package main

import (
	"bytes"
	"errors"

	"github.com/Lobaro/slip"
	"go.bug.st/serial"
)

type Packet struct {
	FrameType byte
	Data      []byte
}

type SerialEndpoint struct {
	port serial.Port

	RX <-chan Packet
	TX chan<- []byte
}

func NewSerialEP(path string) (*SerialEndpoint, error) {
	mode := &serial.Mode{
		BaudRate: baudRate,
		DataBits: 8,
		Parity:   serial.NoParity,
		StopBits: serial.OneStopBit,
	}

	port, err := serial.Open(path, mode)
	if err != nil {
		return nil, err
	}

	rx := make(chan Packet)
	tx := make(chan []byte)

	ep := &SerialEndpoint{
		port: port,
		RX:   rx,
		TX:   tx,
	}

	go ep.rcvLoop(rx)
	go ep.sndLoop(tx)

	return ep, nil
}

func (s *SerialEndpoint) sndLoop(ch <-chan []byte) {
	writer := slip.NewSlipMuxWriter(NewSlowWriter(s.port))

	for {
		data := <-ch

		err := writer.WritePacket(slip.FRAME_COAP, data)
		if err != nil {
			logger.Println("handleCoap:", err)
			continue
		}
	}
}

func (s *SerialEndpoint) rcvLoop(ch chan<- Packet) {
	reader := slip.NewSlipMuxReader(s.port)

	for {
		packet, frame, err := reader.ReadPacket()

		var perr *serial.PortError
		if errors.As(err, &perr) && perr.Code() == serial.PortClosed {
			logger.Fatal("[SerialEndpoint]", err)
		} else if err != nil {
			logger.Println("[SerialEndpoint]", err)
			continue
		}

		packet = bytes.TrimPrefix(packet, []byte{0})
		ch <- Packet{frame, packet}
	}
}

func (s *SerialEndpoint) Close() {
	// close(s.Chan)
	// TODO: Close TTYIO
}
