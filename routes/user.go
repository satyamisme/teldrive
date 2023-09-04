package routes

import (
	"net/http"

	"github.com/divyam234/teldrive/database"
	"github.com/divyam234/teldrive/services"

	"github.com/gin-gonic/gin"
)

func addUserRoutes(rg *gin.RouterGroup) {
	r := rg.Group("/users")
	r.Use(Authmiddleware)
	userService := services.UserService{Db: database.DB}

	r.GET("", func(c *gin.Context) {
		res, err := userService.GetAllUsers(c)

		if err != nil {
			c.AbortWithError(err.Code, err.Error)
			return
		}

		c.JSON(http.StatusOK, res)
	})

	r.GET("/profile", func(c *gin.Context) {
		if c.Query("photo") != "" {
			userService.GetProfilePhoto(c)
		}
	})
}
