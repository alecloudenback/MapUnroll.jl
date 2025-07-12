using MapUnroll
using Documenter

DocMeta.setdocmeta!(MapUnroll, :DocTestSetup, :(using MapUnroll); recursive = true)

makedocs(;
    modules = [MapUnroll],
    authors = "Alec Loudenback <alecloudenback@gmail.com> and contributors",
    sitename = "MapUnroll.jl",
    format = Documenter.HTML(;
        canonical = "https://alecloudenback.github.io/MapUnroll.jl",
        edit_link = "main",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo = "github.com/alecloudenback/MapUnroll.jl",
    devbranch = "main",
)
