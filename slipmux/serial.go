package main

import (
	"bytes"
	"errors"

	"github.com/Lobaro/slip"
	"go.bug.st/serial"
)

type SerialEndpoint struct {
	port serial.Port
	Chan <-chan []byte
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

	ch := make(chan []byte)
	ep := &SerialEndpoint{
		port: port,
		Chan: ch,
	}

	go ep.loop(ch)
	return ep, nil
}

func (s *SerialEndpoint) loop(ch chan<- []byte) {
	reader := slip.NewReader(s.port)
	for {
		packet, _, err := reader.ReadPacket()

		var perr *serial.PortError
		if errors.As(err, &perr) && perr.Code() == serial.PortClosed {
			logger.Fatal("serialChan:", err)
		} else if err != nil {
			logger.Println("serialChan:", err)
			continue
		}

		packet = bytes.TrimPrefix(packet, []byte{0})
		ch <- packet
	}
}

func (s *SerialEndpoint) Close() {
	// close(s.Chan)
	// TODO: Close TTYIO
}
