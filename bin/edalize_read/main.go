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
	"path/filepath"
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

SOURCES_PY = [
	{{- range .FilesPy}}
	"{{.}}",
	{{- end}}
]

SOURCES_XDC = [
	{{- range .FilesXdc}}
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

SOURCES_SDC = [
	{{- range .FilesSdc}}
	"{{.}}",
	{{- end}}
]

SOURCES_TCL = [
	{{- range .FilesTcl}}
	"{{.}}",
	{{- end}}
]

SOURCES_UCF = [
	{{- range .FilesUcf}}
	"{{.}}",
	{{- end}}
]

SOURCES_LPF = [
	{{- range .FilesLpf}}
	"{{.}}",
	{{- end}}
]

SOURCES_PCF = [
	{{- range .FilesPcf}}
	"{{.}}",
	{{- end}}
]

SOURCES_VLT = [
	{{- range .FilesVlt}}
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
	Filename    string
	Files       []string
	IncludeDirs []string
	Headers     []string

	FilesPy  []string
	FilesXdc []string
	FilesSdc []string
	FilesTcl []string
	FilesUcf []string
	FilesLpf []string
	FilesPcf []string
	FilesVlt []string
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
	var args FlagValues
	log.SetPrefix(fmt.Sprintf("%s: ", os.Args[0]))
	flag.BoolVar(&args.notrace, "notrace", false, "")
	flag.StringVar(&args.mode, "mode", "", "")
	flag.StringVar(&args.source, "source", "", "")
	flag.StringVar(&args.output, "output", os.Getenv("EDALIZE_LAUNCHER_OUTPUT"), "")
	flag.StringVar(&args.edafile, "edafile", os.Getenv("EDALIZE_LAUNCHER_EDAFILE"), "")
	flag.Parse()

	if args.source == "" {
		log.Fatalf("flag --source is required")
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
	var out Output

	var edafiles, headers, includeDirs []string
	for _, file := range edaFile.Files {
		var fullPath string
		if strings.HasPrefix(file.Name, "../") {
			fullPath = strings.TrimPrefix(file.Name, "../")
		} else {
			fullPath = filepath.Join(args.source, file.Name)
		}
		if file.IsIncludeFile {
			includeDirs = append(includeDirs, path.Dir(fullPath))
			headers = append(headers, fullPath)
		} else if strings.HasSuffix(fullPath, ".py") {
			out.FilesPy = append(out.FilesPy, fullPath)
		} else if strings.HasSuffix(fullPath, ".xdc") {
			out.FilesXdc = append(out.FilesXdc, fullPath)
		} else if strings.HasSuffix(fullPath, ".sdc") {
			out.FilesSdc = append(out.FilesSdc, fullPath)
		} else if strings.HasSuffix(fullPath, ".tcl") {
			out.FilesTcl = append(out.FilesTcl, fullPath)
		} else if strings.HasSuffix(fullPath, ".ucf") {
			out.FilesUcf = append(out.FilesUcf, fullPath)
		} else if strings.HasSuffix(fullPath, ".lpf") {
			out.FilesLpf = append(out.FilesLpf, fullPath)
		} else if strings.HasSuffix(fullPath, ".pcf") {
			out.FilesPcf = append(out.FilesPcf, fullPath)
		} else if strings.HasSuffix(fullPath, ".vlt") {
			out.FilesVlt = append(out.FilesVlt, fullPath)
		} else {
			edafiles = append(edafiles, fullPath)
		}
	}

	// Write output
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
