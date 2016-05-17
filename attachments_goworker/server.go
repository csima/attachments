
import (
    "fmt"
    "os"
    "time"
    "github.com/gorilla/sessions"
    "github.com/codegangsta/negroni"
    "net/http"
    "strings"
    //"github.com/davecgh/go-spew/spew"
)

func main() {
    apiServer()
}

func apiServer() {
    fmt.Printf("%s:%s\n", os.Getenv("IP"), os.Getenv("PORT"))
    router := mux.NewRouter()

    n := negroni.Classic()
	
    router.HandleFunc("/search", searchFlightsAPI)
    
    n.UseHandler(router)
    n.Run("0.0.0.0:8080")
}