package main

import (
	"net"
)

type CoapEndpoint struct {
	lp   net.PacketConn
	Chan <-chan []byte
}

func NewCoapEP(addr string) (*CoapEndpoint, error) {
	lp, err := net.ListenPacket("udp", addr)
	if err != nil {
		return nil, err
	}

	ch := make(chan []byte)
	ep := &CoapEndpoint{
		lp:   lp,
		Chan: ch,
	}

	go ep.loop(ch)
	return ep, nil
}

func (c *CoapEndpoint) loop(ch chan<- []byte) {
	buf := make([]byte, bufSize)

	for {
		n, _, err := c.lp.ReadFrom(buf)
		if err != nil {
			logger.Println("coapChan:", err)
			continue
		}

		ch <- buf[0:n]
	}
}

func (c *CoapEndpoint) Close() {
	// close(c.Chan)
	c.lp.Close()
}
