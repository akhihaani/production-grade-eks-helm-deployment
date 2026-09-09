output "memos_public_subnet" {
  value = [for s in aws_subnet.memos_public_subnet : s.id]
}

output "memos_private_subnet" {
  value = [for s in aws_subnet.memos_private_subnet : s.id]
}

output "memos_vpc" {
  value = aws_vpc.memos_vpc.id
}
