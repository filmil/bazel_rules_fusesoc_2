// edalize_launch
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path"
	"sort"
	"strings"
	"text/template"

	"gopkg.in/yaml.v3"
)

var (
	bzlTemplate = template.Must(template.New("bzl").Parse(`##
## GENERATED FILE. DO NOT EDIT!

SOURCES = [
	{{- range .Files}}
	"{{.}}",
	{{- end}}
]

HEADERS = [
	{{- range .Headers}}
	"{{.}}",
	{{- end}}
]

INCLUDE_DIRS = [
	{{- range .IncludeDirs}}
	"{{.}}",
	{{- end}}
]
`))
)

type FlagValues struct {
	notrace bool
	mode    string
	source  string
	edafile string

	output string
}

type Output struct {
	Filename    string   `json:"filename"`
	Files       []string `json:"files"`
	IncludeDirs []string `json:"include_dirs"`
	Headers     []string `json:"headers"`
}

type File struct {
	Core          string `yaml:"core"`
	FileType      string `yaml:"file_type"`
	Name          string `yaml:"name"`
	IsIncludeFile bool   `yaml:"is_include_file"`
}

type EdaFile struct {
	Dependencies map[string][]string `yaml:"dependencies"`
	Files        []File              `yaml:"files"`
}

func DecodeEdafile(r io.Reader) (EdaFile, error) {
	var e EdaFile
	d := yaml.NewDecoder(r)
	if err := d.Decode(&e); err != nil {
		return e, fmt.Errorf("error while parsing edafile: %w", err)
	}
	return e, nil
}

// Unique retains a stable set of unique strings from a slice.
func Unique(in []string) []string {
	s := make(map[string]struct{})
	for _, v := range in {
		s[v] = struct{}{}
	}
	var ret []string

	for k := range s {
		ret = append(ret, k)
	}
	sort.Strings(ret)
	return ret
}

func main() {
	// Work around the first arg.
	os.Args = append(os.Args[0:0], os.Args[2:]...)

	var args FlagValues
	log.SetPrefix(fmt.Sprintf("%s: ", os.Args[0]))
	flag.BoolVar(&args.notrace, "notrace", false, "")
	flag.StringVar(&args.mode, "mode", "", "")
	flag.StringVar(&args.source, "source", "", "")
	flag.StringVar(&args.output, "output", os.Getenv("EDALIZE_LAUNCHER_OUTPUT"), "")
	flag.StringVar(&args.edafile, "edafile", os.Getenv("EDALIZE_LAUNCHER_EDAFILE"), "")
	flag.Parse()

	if args.source == "" {
		log.Fatalf("no source file: %q", args.source)
	}

	f, err := os.Create(args.output)
	if err != nil {
		log.Fatalf("could not create file: %q: %v", args.output, err)
	}
	defer func() {
		if err := f.Close(); err != nil {
			log.Printf("could not close: %q: %v", args.output, err)
		}
	}()

	edaYaml, err := os.Open(args.edafile)
	if err != nil {
		log.Fatalf("could not read edafile: %q: %v", args.edafile, err)
	}
	edaFile, err := DecodeEdafile(edaYaml)
	if err != nil {
		log.Fatalf("could not parse edafile: %q: %v", args.edafile, err)
	}
	var edafiles, headers, includeDirs []string
	for _, file := range edaFile.Files {
		fullPath := strings.TrimPrefix(file.Name, "../")
		if file.IsIncludeFile {
			includeDirs = append(includeDirs, path.Dir(fullPath))
			headers = append(headers, fullPath)
		} else {
			edafiles = append(edafiles, fullPath)
		}
	}

	// Write output
	var out Output

	out.Filename = args.source
	out.Files = edafiles
	out.IncludeDirs = Unique(includeDirs)
	out.Headers = headers

	e := json.NewEncoder(f)
	e.SetIndent("", "  ")

	if err := bzlTemplate.Execute(f, out); err != nil {
		log.Fatalf("could not encode into: %q: %v", args.output, err)
	}
}
