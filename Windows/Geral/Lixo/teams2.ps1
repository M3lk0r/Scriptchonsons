try{
#Remove teams classico
\\ad01\util$\softwares\teamsbootstrapper.exe -u
} catch {

}

try {
#Instala
\\ad01\util$\softwares\teamsbootstrapper.exe -p -o "\\ad01\util$\softwares\MSTeams-x64.msix"
} catch {

}
