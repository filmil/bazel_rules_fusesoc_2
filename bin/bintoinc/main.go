// bintoinc creates byte definitions for inclusion into assembly source.
package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
)

// Convert converts a binary file into a set of bytes suitable for inclusion
// into an assembly source.
func Convert(r io.Reader) error {
	fmt.Printf("\t// Generated, do not edit.\n")
	b := make([]byte, 16)
	for {
		n, err := r.Read(b)
		v := make([]string, 16)
		if n > 0 {
			for i := 0; i < n; i++ {
				v[i] = fmt.Sprintf("0x%02x", b[i])
			}
			fmt.Printf("\t.byte %s\n", strings.Join(v[:n], ", "))
		}
		if err == io.EOF {
			break
		}
	}
	return nil
}

func main() {
	log.SetPrefix(os.Args[0])
	flag.Parse()

	if err := Convert(os.Stdin); err != nil {
		log.Fatalf("error during conversion: %v", err)
	}
}
