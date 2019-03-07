import Foundation
import Kitura
import LoggerAPI
import HeliumLogger
import Application
import FileKit

import CouchDB


let connProperties = ConnectionProperties(
    host: "217b8ae5-dfa4-4f56-a420-b3d1131f3494-bluemix.cloudantnosqldb.appdomain.cloud",         // http address ---> For Local Host it is http://127.0.0.1
    port: 443,         // http port ------> For Local Host it is 5984
    secured: true,   // https or http For Local Host it is false
    username: "217b8ae5-dfa4-4f56-a420-b3d1131f3494-bluemix",      // admin username For Local Host it is admin
    password: "899562c950dcba765a94bb86ebd9656be688398ea62edf319f9a64981c0316b8"       // admin password For Local Host it is 123456
)



public class FileHandler:NSObject{
    
    public func RemoveAllFiles(){
        let stringUrl = FileKit.projectFolder
        let url = URL.init(fileURLWithPath: "\(stringUrl)/Sources/Application/Temp/", isDirectory: true)
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: url,
                                                                       includingPropertiesForKeys: nil,options: [])
            for fileURL in fileURLs {
                if fileURL.pathExtension == "jpg" || fileURL.pathExtension == "png"{
                    try FileManager.default.removeItem(at: fileURL)}}}
        catch  { print(error) }
    }
    
    public func InsertFileIntoTempFolder(fileName:String,data:Data){
        do{
            let stringUrl = FileKit.projectFolder
            let url = URL.init(fileURLWithPath: "\(stringUrl)/Sources/Temp/\(fileName)", isDirectory: true)
            try data.write(to: url, options: .atomic)
        }catch{print("File can't be stored")}
    }
    
    public func MoveFileToPerminentFolder(imagePath:String){
        let fileManger = FileManager.default
        let stringUrl = FileKit.projectFolder
        _  = URL.init(fileURLWithPath: "\(stringUrl)/Sources/Temp/\(imagePath)", isDirectory: true)
        do {
            try fileManger.moveItem(atPath: "\(stringUrl)/Sources/Temp/\(imagePath)", toPath: "\(stringUrl)/Sources/Perminent/\(imagePath)")
            //try fileManger.removeItem(at: path)
        }
        catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        }
    }
}






struct CricketersModel:Document {
    var _id: String?
    var _rev: String?
    let name:String
    let role:String
    let team:String
    let type:String
    let title:String
    let age:String
    let imagePath:String
    
    init?(name:String,role:String,team:String,type:String,title:String,age:String,imagePath:String){
        self.name = name
        self.role = role
        self.team = team
        self.type = type
        self.title = title
        self.age = age
        self.imagePath = imagePath
    }
}

struct GetCricketsModel:Document {
    var _id: String?
    var _rev: String?
    let name:String
    let role:String
    let team:String
    let type:String
    let title:String
    let age:String
    let imagePath:String
    init?(name:String,role:String,team:String,type:String,title:String,age:String,imagePath:String,_id:String,_rev:String){
        self.name = name
        self.role = role
        self.team = team
        self.type = type
        self.title = title
        self.age = age
        self.imagePath = imagePath
        self._id = _id
        self._rev = _rev
    }
}

let couchDBClient = CouchDBClient(connectionProperties: connProperties)

let router = Router()




router.post(middleware: BodyParser())


router.all("/Sources", middleware: StaticFileServer(path: "./Sources"))


router.get("/testFileKit"){request,responce,next in
    let stringUrl = FileKit.projectFolder
    responce.send(json: ["path":stringUrl])
    next()

}


router.post("/image") { request, response, next in
    if let body = request.body?.asMultiPart{
        let rawdata = body[0]
        let fileHandler = FileHandler()
        fileHandler.RemoveAllFiles()
        if let data = rawdata.body.asRaw{
            let stringUrl = FileKit.projectFolder
            let manager = FileManager.default
            do{
                try manager.createDirectory(atPath: "\(stringUrl)/Sources/Temp", withIntermediateDirectories: true, attributes: nil)}catch{}
            fileHandler.InsertFileIntoTempFolder(fileName: rawdata.filename, data: data)
            response.send(json: ["filename":"\(rawdata.filename)","contentType":"\(rawdata.type)","path":"Temp/\(rawdata.filename)"])}
        else{response.send("Request is not multi part")}
    }
    next()
}

router.post("/postCricketers"){request,responce,next in
    var originalPath = ""
    if let body = request.body?.asJSON{
        let name = body["name"]
        let role = body["role"]
        let team = body["team"]
        let type = body["type"]
        let title = body["title"]
        let age = body["age"]
        let imagePath = body["imagePath"]
        if connProperties.host == "http:127.0.0.1:8080"{
            originalPath = "http:127.0.0.1:8080/Sources/Perminent/\(imagePath as! String)"
        }
        else{
           originalPath = "https://crickbuzz.eu-gb.mybluemix.net/Sources/Perminent/\(imagePath as! String)"
        }
        let doc = CricketersModel.init(name: name as! String , role: role as! String, team: team as! String, type: type as! String , title: title as! String , age: age as! String, imagePath: originalPath)
        couchDBClient.retrieveDB("cricketers_db") { (database, error) in
            if let database = database {
                database.create(doc!) { (response, error) in
                    if response != nil {
                        let manager = FileManager.default
                        let fileHandler = FileHandler()
                        let stringUrl = FileKit.projectFolder
                        do{
                            try manager.createDirectory(atPath: "\(stringUrl)/Sources/Perminent", withIntermediateDirectories: true, attributes: nil)}catch{}
                        fileHandler.MoveFileToPerminentFolder(imagePath: imagePath as! String)
                        responce.send(json: ["message":"Record Inserted Sucsessfully","sucsses":true])
                    }
                }
            }
        }
    }
    else{
        responce.status(.badRequest)
        responce.send(json: ["message":"Record insertion failure","sucsses":false])
        return
    }
    
    
    next()
}

router.get("/getAllCricketers"){request,responce,next in
    couchDBClient.retrieveDB("cricketers_db") { (database, error) in
        if let database = database {
            database.retrieveAll(includeDocuments: true){docs, error in
                var cricketersArray = [GetCricketsModel]()
                if let docs = docs{
                    for documents in docs.rows{
                        let dataDocs = documents["doc"]
                        let recordDocs = dataDocs as! [String:Any]
                        if  recordDocs["name"] != nil{
                            let id = recordDocs["_id"] as! String
                            let rev = recordDocs["_rev"]as! String
                            let name = recordDocs["name"] as! String
                            let role = recordDocs["role"] as! String
                            let team = recordDocs["team"] as! String
                            let type = recordDocs["type"] as! String
                            let title = recordDocs["title"] as! String
                            let age = recordDocs["age"] as! String
                            let imagePath = recordDocs["imagePath"] as! String
                            let model = GetCricketsModel.init(name: name, role: role, team: team, type: type, title: title, age: age,imagePath:imagePath,_id:id,_rev:rev)
                            cricketersArray.append(model!)
                            
                        }
                    }
                    responce.send(json: ["Cricketers":cricketersArray])
                }
            }
        }
    }
    next()
}



Kitura.addHTTPServer(onPort: 8080, with: router)
Kitura.run()

