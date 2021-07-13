Deploy Module {
    By PSGalleryModule {
        FromSource Templatename
        To PSGallery
        WithOptions @{
            
            ApiKey = $ENV:PSGalleryKey
        }
    }
}