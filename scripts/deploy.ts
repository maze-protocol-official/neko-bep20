import {ethers} from "hardhat"
import { Contract, BigNumber } from 'ethers';
import fs = require('fs')
import path = require('path')

function _dir(d: string) {
    return path.join(__dirname, d)
}

const _dbFile = _dir('../local/deploy.json')

function dbSet(k: string, v: string) {
    const b = fs.existsSync(_dbFile)
    let o = b ? JSON.parse(
        fs.readFileSync(_dbFile, 'ascii')
    ) : {}

    o[k] = v
    fs.writeFileSync(_dbFile, JSON.stringify(o))
}

function dbGet(k: string): string {
    const b = fs.existsSync(_dbFile)
    if (!b)
        return ''

    let o = JSON.parse(fs.readFileSync(_dbFile, 'ascii'))
    return o[k]
}

async function deployContract(id: string, name: string, args: any[], libraries: Record<string, string> = {}): Promise<Contract> {
    let addr = dbGet(id)

    if (addr) {
        return (await ethers.getContractFactory(name, {
            libraries: libraries
        })).attach(addr)
    }

    const lib = await ethers.getContractFactory(name, {
        libraries: libraries
    })

    const r = await lib.deploy(...args)
    dbSet(id, r.address)
    return r
}

interface NekoInfo {
    NekoToken: Contract
    LockOwner: Contract
    OwnerNeko: Contract
}

let spender = '0x65e21654465EfBea2bfE40918892DcFC12151E25'

let ownersArray = ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8","0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"]

async function main() {
    let ret: NekoInfo = <any>{}

    const [alice] = await ethers.getSigners()

    ret.NekoToken = await deployContract("NEKOToken", "NEKOToken", [alice.address])
    await ret.NekoToken.mint(spender, BigNumber.from('4032000000000000000000000'))

    ret.LockOwner = await deployContract("LockOwner", "LockOwner", [ret.NekoToken.address])

    ret.OwnerNeko = await deployContract("OwnerNeko", "OwnerNeko", [ret.NekoToken.address, ret.LockOwner.address, ownersArray])

    await  ret.NekoToken.transferOwnership(ret.OwnerNeko.address);

    for (let k of Object.keys(ret)) {
        let v: Contract | NekoInfo = (<any>ret)[k]
        console.log(`${k} = ${(<any>v).address}`)
    }
}

main().catch(console.error)

